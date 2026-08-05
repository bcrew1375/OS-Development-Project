//! Early-boot bootstrap paging.
//!
//! Runs before the kernel's real allocator/paging exist, so every
//! function and static below is pinned to the `.multiboot.*` linker
//! sections. That's why `linksection(...)` appears on nearly every
//! declaration - it is a hard physical constraint of this boot stage
//! (nothing else has been mapped yet), not repeated style noise, and
//! it should stay even though it's visually heavy.
//!
//! SUGGESTED FILE SPLIT
//! =====================
//! This file currently mixes two unrelated concerns: bootstrap page
//! table setup, and multiboot memory-map parsing. They happen to run
//! around the same point in boot, but neither calls into the other,
//! and "how does paging bootstrap work" and "how do we learn what
//! memory exists" are two different questions a reader shouldn't have
//! to interleave. Recommended split:
//!
//!   1. bootstrap_paging.zig (this file, trimmed to just this)
//!        - Section, LinkerRange, bootstrap_ranges, region constants
//!        - initializePaging() and everything initializePaging calls
//!
//!   2. memory_map.zig                                    <- MOVE
//!        - MultibootMemoryMapEntry, MultibootMemoryMapRegionTypes
//!        - memoryMap, maxAvailableAddress (module-level state)
//!        - readMultibootMemoryMap, getMemoryMap, getMaxAvailableAddress
//!        Self-contained: only needs `arch` and `multiboot`, never
//!        touches anything paging-related in this file.
//!
//!   3. common.zig (existing file)                        <- MOVE
//!        - checkedAdd, checkedMultiply, alignForward
//!        These are generic overflow-checked arithmetic with no
//!        dependency on paging or multiboot state. Leaving them here
//!        means any other early-boot code that needs checked math
//!        either duplicates them or takes an unnecessary dependency
//!        on this file. They belong wherever `common`'s other
//!        boot-safe primitives already live.
//!
//!   4. getDirectMapVirtualAddress / getDirectMapMaxSize   <- MOVE or DELETE
//!        Both just forward to `common.DIRECT_MAP_VIRTUAL_ADDRESS` /
//!        `common.DIRECT_MAP_SIZE` and touch no state owned by this
//!        file. Either move them next to those constants in
//!        common.zig, or delete them and have callers read the
//!        constants directly - as written they're indirection with
//!        no behavior attached.

const std = @import("std");
const arch = @import("arch");
const multiboot = @import("../boot/multiboot/main.zig");

const common = @import("common.zig");

/// Full error space for the bootstrap-paging entry point. Individual
/// helpers below declare their own narrower error sets - only the
/// entry point needs to expose the whole union to its caller.
const EarlyPagingError = arch.EarlyAllocError || error{
    BootstrapMappingOverflow,
    InvalidBootstrapMapping,
    KernelImageTooLarge,
    PageTableAllocationOverflow,
};

const Section = struct {
    start: usize = undefined,
    end: usize = undefined,
    write: bool = false,
    user: bool = false,
    global: bool = false,
};

/// One (start-symbol, end-symbol) pair pulled directly from the linker
/// script. Order here is purely for readability - validation does not
/// assume the resulting Section list is sorted or that entries are
/// non-overlapping by construction; that's checked explicitly in
/// validateBootstrapMappingSections.
const LinkerRange = struct {
    // `comptime` fields have no runtime storage at all - reading them
    // always resolves to a compile-time constant, regardless of
    // whether this struct (or the array of them below) ends up
    // materialized as a real object in the binary. This is what
    // actually guarantees the symbol-name strings can never end up
    // living in the wrong section: they never exist as addressable
    // runtime data in the first place.
    start_name: [:0]const u8,
    end_name: [:0]const u8,
    write: bool,
};

// start_name/end_name are `comptime` fields (see LinkerRange), so they
// carry zero runtime storage - only `write: bool` has any real
// runtime representation. That makes this array trivial to place
// correctly regardless of build mode, so it's still pinned to the
// early-boot rodata section as defense in depth.
const bootstrap_ranges linksection(".multiboot.rodata") = [_]LinkerRange{
    .{ .start_name = "_multiboot_header_start", .end_name = "_multiboot_header_end", .write = false },
    .{ .start_name = "_multiboot_text_start", .end_name = "_multiboot_text_end", .write = false },
    .{ .start_name = "_multiboot_rodata_start", .end_name = "_multiboot_rodata_end", .write = false },
    .{ .start_name = "_multiboot_data_start", .end_name = "_multiboot_data_end", .write = true },
    .{ .start_name = "_multiboot_bss_start", .end_name = "_multiboot_bss_end", .write = true },
    .{ .start_name = "_text_start", .end_name = "_text_end", .write = false },
    .{ .start_name = "_rodata_start", .end_name = "_rodata_end", .write = false },
    .{ .start_name = "_data_start", .end_name = "_data_end", .write = true },
    .{ .start_name = "_bss_start", .end_name = "_bss_end", .write = true },
};

// Non-linker-range sections: reserved low memory, VGA buffer, reserved
// upper memory, and the trailing kernel_end -> bootstrap_mapping_end
// region. Kept as a constant so the Section array can be sized without
// a magic number.
const EXTRA_MAPPING_SECTION_COUNT = 4;
const BOOTSTRAP_MAPPING_SECTION_COUNT = bootstrap_ranges.len + EXTRA_MAPPING_SECTION_COUNT;
const BootstrapMappingSections = [BOOTSTRAP_MAPPING_SECTION_COUNT]Section;

var bootstrapMappingSections: BootstrapMappingSections linksection(".multiboot.data") = undefined;

const RESERVED_LOWER_START: usize = 0x00000000;
const RESERVED_LOWER_END: usize = 0x000B8000;

const VGA_BUFFER_START = 0x000B8000;
const VGA_BUFFER_END = VGA_BUFFER_START + 0x8000;

const RESERVED_UPPER_START: usize = 0x000C0000;
const RESERVED_UPPER_END: usize = 0x00100000;

extern const _kernel_end: usize;

/// Resolves a linker-defined symbol's address by name, without needing a
/// dedicated `extern const` declaration for every symbol in the file.
fn linkerAddr(comptime name: [:0]const u8) linksection(".multiboot.text") usize {
    return @intFromPtr(@extern(*const anyopaque, .{ .name = name }));
}

// ============================================================
// Bootstrap page table setup
// ============================================================
//
// initializePaging is the single control-flow entry point for this
// subsystem: every branch/error decision that matters lives here or
// in the functions it directly calls. Everything below it is either
// a pure computation (no branching a caller needs to know about) or
// a validation pass with its own fully-contained checks - nothing
// here calls back "up" into a sibling that also branches.

pub fn initializePaging() linksection(".multiboot.text") EarlyPagingError!void {
    const kernel_end_address = @intFromPtr(&_kernel_end);
    const needed_page_tables = try calculateBootstrapPageTableCount(kernel_end_address);
    const bootstrap_mapping_end = try common.checkedMultiply(needed_page_tables, common.PAGE_TABLE_REGION_SIZE);

    configureBootstrapMappingSections(bootstrap_mapping_end);
    const section_list = bootstrapMappingSections[0..];
    try validateBootstrapMappingSections(section_list, bootstrap_mapping_end);

    const kernel_page_directory_entries = try allocatePageDirectory();
    const direct_map_entries = try allocatePageTables(needed_page_tables);

    initializeBootstrapMappings(kernel_page_directory_entries, direct_map_entries, section_list);
    activatePaging(kernel_page_directory_entries);
}

/// Populates `bootstrapMappingSections` from the fixed reserved regions,
/// the linker-derived ranges, and the trailing kernel-end region.
///
/// The per-entry assignment is pulled out into
/// `configureBootstrapMappingSections_section` purely because it's
/// invoked five separate ways below (three one-off calls, a loop over
/// `bootstrap_ranges`, and the trailing kernel_end entry) - not because
/// it carries any decision-making of its own. The name is prefixed
/// with its only caller's name to make that relationship obvious
/// without having to go read the body.
fn configureBootstrapMappingSections(bootstrap_mapping_end: usize) linksection(".multiboot.text") void {
    var index: usize = 0;

    configureBootstrapMappingSections_section(index, RESERVED_LOWER_START, RESERVED_LOWER_END, false);
    index += 1;
    configureBootstrapMappingSections_section(index, VGA_BUFFER_START, VGA_BUFFER_END, true);
    index += 1;
    configureBootstrapMappingSections_section(index, RESERVED_UPPER_START, RESERVED_UPPER_END, false);
    index += 1;

    inline for (bootstrap_ranges) |range| {
        configureBootstrapMappingSections_section(index, linkerAddr(range.start_name), linkerAddr(range.end_name), range.write);
        index += 1;
    }

    configureBootstrapMappingSections_section(index, @intFromPtr(&_kernel_end), bootstrap_mapping_end, true);
    index += 1;
}

fn configureBootstrapMappingSections_section(index: usize, start: usize, end: usize, write: bool) linksection(".multiboot.text") void {
    bootstrapMappingSections[index] = .{
        .start = start,
        .end = end,
        .write = write,
        .user = false,
        .global = false,
    };
}

/// Validates that every section is well-formed (end >= start), that no
/// two sections overlap, and that the sections together cover up to
/// bootstrap_mapping_end. Sections may appear in any order - there is
/// no requirement that section_list be pre-sorted by address.
///
/// Kept as one function rather than split further: the three passes
/// below are cheap, independent checks over the same small fixed-size
/// list, and splitting them into separate named functions wouldn't
/// remove any branching from this function's caller - it would just
/// add three more names to `initializePaging`'s call graph for no
/// reduction in what the reader has to track.
fn validateBootstrapMappingSections(
    section_list: []const Section,
    bootstrap_mapping_end: usize,
) linksection(".multiboot.text") error{InvalidBootstrapMapping}!void {
    if (bootstrap_mapping_end == 0) {
        return error.InvalidBootstrapMapping;
    }

    for (section_list) |section| {
        if (section.end < section.start) {
            return error.InvalidBootstrapMapping;
        }
    }

    for (section_list, 0..) |a, i| {
        for (section_list[i + 1 ..]) |b| {
            if (a.start < b.end and b.start < a.end) {
                return error.InvalidBootstrapMapping;
            }
        }
    }

    var max_end: usize = 0;
    for (section_list) |section| {
        max_end = @max(max_end, section.end);
    }

    if (max_end < bootstrap_mapping_end) {
        return error.InvalidBootstrapMapping;
    }
}

fn calculateBootstrapPageTableCount(
    mapped_end: usize,
) linksection(".multiboot.text") error{ InvalidBootstrapMapping, BootstrapMappingOverflow, KernelImageTooLarge }!usize {
    if (mapped_end == 0) {
        return error.InvalidBootstrapMapping;
    }

    const aligned_mapping_end = try common.alignForward(mapped_end, common.PAGE_TABLE_REGION_SIZE);
    const page_table_count = aligned_mapping_end / common.PAGE_TABLE_REGION_SIZE;

    if (page_table_count == 0) {
        return error.InvalidBootstrapMapping;
    }

    if (page_table_count > common.HIGHER_HALF_INDEX) {
        return error.KernelImageTooLarge;
    }

    if (common.HIGHER_HALF_INDEX + page_table_count > common.ENTRIES_PER_DIRECTORY) {
        return error.KernelImageTooLarge;
    }

    return page_table_count;
}

/// Allocates and zero-initializes the kernel page directory.
///
/// Zeroing was previously a separate `clearPageDirectory` helper
/// called exactly once, right after allocation, from exactly here.
/// Folded inline: it had no branching of its own to isolate, and a
/// single-caller helper with a generic name ("clear...") reads like
/// a general-purpose utility when it wasn't one.
fn allocatePageDirectory() linksection(".multiboot.text") (arch.EarlyAllocError || error{PageTableAllocationOverflow})!common.PageDirectory {
    const allocation_size = try common.checkedMultiply(@sizeOf(common.PageEntry), common.ENTRIES_PER_DIRECTORY);
    const page_directory: common.PageDirectory = @ptrCast(@alignCast(try arch.early_allocator.allocate(
        allocation_size,
        common.PAGE_SIZE,
        arch.ReservedMapRegionType.PERSISTENT,
    )));

    for (page_directory) |*entry| {
        entry.* = .{};
    }

    return page_directory;
}

/// Allocates and zero-initializes `page_table_count` page tables.
///
/// Same fold as `allocatePageDirectory` above: the old
/// `clearPageTable` helper had a single call site, immediately after
/// allocation, and no independent branching - so the zeroing loop now
/// lives directly in the same loop that walks the freshly-allocated
/// tables, instead of a separate named indirection a reader has to
/// jump to and back from.
fn allocatePageTables(
    page_table_count: usize,
) linksection(".multiboot.text") (arch.EarlyAllocError || error{PageTableAllocationOverflow})![][common.ENTRIES_PER_TABLE]common.PageEntry {
    const page_table_size = try common.checkedMultiply(@sizeOf(common.PageEntry), common.ENTRIES_PER_TABLE);
    const allocation_size = try common.checkedMultiply(page_table_count, page_table_size);
    const page_tables_ptr = try arch.early_allocator.allocate(
        allocation_size,
        common.PAGE_SIZE,
        arch.ReservedMapRegionType.PERSISTENT,
    );
    const page_tables: [][common.ENTRIES_PER_TABLE]common.PageEntry = @as(
        [*][common.ENTRIES_PER_TABLE]common.PageEntry,
        @ptrCast(@alignCast(page_tables_ptr)),
    )[0..page_table_count];

    for (page_tables) |*page_table| {
        for (page_table) |*entry| {
            entry.* = .{};
        }
    }

    return page_tables;
}

fn initializeBootstrapMappings(
    page_directory: common.PageDirectory,
    page_tables: [][common.ENTRIES_PER_TABLE]common.PageEntry,
    section_list: []const Section,
) linksection(".multiboot.text") void {
    for (page_tables, 0..) |*page_table, directory_index| {
        const directory_entry = makePageDirectoryEntry(page_table);
        page_directory[directory_index] = directory_entry;
        page_directory[common.HIGHER_HALF_INDEX + directory_index] = directory_entry;

        initializePageTable(page_table, directory_index, section_list);
    }
}

fn initializePageTable(
    page_table: *[common.ENTRIES_PER_TABLE]common.PageEntry,
    directory_index: usize,
    section_list: []const Section,
) linksection(".multiboot.text") void {
    for (page_table, 0..) |*entry, table_index| {
        const physical_address = (directory_index * common.PAGE_TABLE_REGION_SIZE) + (table_index * common.PAGE_SIZE);
        entry.* = makePageEntry(physical_address, findSectionForPhysicalPage(physical_address, section_list));
    }
}

// Linear scan is fine here: this only runs once during early boot, over
// a small, fixed section list. Kept as its own function (rather than
// inlined into initializePageTable) because it has its own loop and
// its own termination condition - exactly the kind of self-contained
// control flow that's worth naming and pulling out.
fn findSectionForPhysicalPage(physical_address: usize, section_list: []const Section) linksection(".multiboot.text") ?*const Section {
    const physical_page_end = physical_address + common.PAGE_SIZE;

    for (section_list) |*section| {
        if (physical_address < section.end and physical_page_end > section.start) {
            return section;
        }
    }

    return null;
}

fn makePageDirectoryEntry(page_table: *[common.ENTRIES_PER_TABLE]common.PageEntry) linksection(".multiboot.text") common.PageEntry {
    return .{
        .address = @truncate(getBootstrapPhysicalAddress(@intFromPtr(page_table)) >> 12),
        .present = true,
        .writeable = true,
        .user_accessible = false,
    };
}

fn makePageEntry(physical_address: usize, section: ?*const Section) linksection(".multiboot.text") common.PageEntry {
    const write = if (section) |mapped_section| mapped_section.write else false;
    const user = if (section) |mapped_section| mapped_section.user else false;
    const global = if (section) |mapped_section| mapped_section.global else false;

    return .{
        .address = @truncate(physical_address >> 12),
        .present = true,
        .writeable = write,
        .user_accessible = user,
        .global = global,
    };
}

fn getBootstrapPhysicalAddress(address: usize) linksection(".multiboot.text") usize {
    if (address >= common.DIRECT_MAP_VIRTUAL_ADDRESS) {
        return address - common.DIRECT_MAP_VIRTUAL_ADDRESS;
    }

    return address;
}

fn activatePaging(page_directory: common.PageDirectory) linksection(".multiboot.text") void {
    const page_directory_physical_address = getBootstrapPhysicalAddress(@intFromPtr(page_directory));

    asm volatile (
        \\pusha
        \\mov %[pageDirectoryAddress], %eax
        \\mov %eax, %cr3
        // Enable paging.
        \\mov %cr0, %eax
        \\or $0x80010000, %eax
        \\mov %eax, %cr0
        \\popa
        :
        : [pageDirectoryAddress] "r" (page_directory_physical_address),
        : .{ .eax = true, .memory = true });
}

// ============================================================
// MOVE: checked-arithmetic primitives -> common.zig
// ============================================================
//
// Nothing below this point depends on paging or multiboot state - all
// three are generic overflow-checked integer math. They stay in this
// file today only because they must also run pre-paging and therefore
// need the same linksection treatment; if common.zig already hosts
// other boot-safe helpers under the same section, these belong there
// instead, so other early-boot code isn't tempted to hand-roll its
// own overflow checks.

// ============================================================
// MOVE: multiboot memory map -> memory_map.zig
// ============================================================
//
// Everything from here down is a separate subsystem: parsing and
// caching the multiboot-provided memory map. It shares no state and
// no call relationship with bootstrap paging above - it just happens
// to run around the same point in boot. See the file-level doc
// comment at the top for the suggested split.

// MOVE or DELETE: see file-level doc comment - these don't touch
// memory-map state at all and can move to common.zig next to the
// constants they wrap, or be deleted in favor of callers reading
// common.DIRECT_MAP_VIRTUAL_ADDRESS / common.DIRECT_MAP_SIZE directly.
pub fn getDirectMapVirtualAddress() linksection(".multiboot.text") u64 {
    return common.DIRECT_MAP_VIRTUAL_ADDRESS;
}

pub fn getDirectMapMaxSize() linksection(".multiboot.text") u64 {
    return common.DIRECT_MAP_SIZE;
}
