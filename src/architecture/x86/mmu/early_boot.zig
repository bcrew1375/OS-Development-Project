const arch = @import("arch");
const multiboot = @import("../boot/main.zig");

const common = @import("common.zig");

const MultibootMemoryMapEntry = extern struct {
    size: u32,
    address: u64,
    length: u64,
    region_type: MultibootMemoryMapRegionTypes,
};

const MultibootMemoryMapRegionTypes = enum(u32) {
    AVAILABLE = 1,
    RESERVED = 2,
    ACPI_RECLAIMABLE = 3,
    ACPI_NVS = 4,
    BAD_MEMORY = 5,
    _,
};

var EarlyPageTableCounter: usize linksection(".multiboot.data") = 0;

var memoryMap: arch.MemoryMap linksection(".multiboot.data") = arch.MemoryMap{};

var maxAvailableAddress: u64 linksection(".multiboot.data") = 0;

const Section = struct {
    start: usize = undefined,
    end: usize = undefined,
    protection: arch.PageProtection = arch.PageProtection{ .write = false, .user = false },
};

var sections: [12]Section linksection(".multiboot.data") = undefined;

const RESERVED_LOWER_START: usize = 0x00000000;
const RESERVED_LOWER_END: usize = 0x000B8000;

const VGA_BUFFER_START = 0x000B8000;
const VGA_BUFFER_END = VGA_BUFFER_START + 0x8000;

const RESERVED_UPPER_START: usize = 0x000C0000;
const RESERVED_UPPER_END: usize = 0x00100000;

extern const _kernel_start: usize;
extern const _kernel_end: usize;

extern const _multiboot_header_start: usize;
extern const _multiboot_header_end: usize;
extern const _multiboot_text_start: usize;
extern const _multiboot_text_end: usize;
extern const _multiboot_rodata_start: usize;
extern const _multiboot_rodata_end: usize;
extern const _multiboot_data_start: usize;
extern const _multiboot_data_end: usize;
extern const _multiboot_bss_start: usize;
extern const _multiboot_bss_end: usize;

extern const _text_start: usize;
extern const _text_end: usize;
extern const _rodata_start: usize;
extern const _rodata_end: usize;
extern const _data_start: usize;
extern const _data_end: usize;
extern const _bss_start: usize;
extern const _bss_end: usize;

pub fn initializePaging() linksection(".multiboot.text") !void {
    // const available_ram = getMaxAvailableAddress();
    // const direct_map_size = @min(getDirectMapMaxSize(), available_ram);

    const kernel_end_address = @intFromPtr(&_kernel_end);

    //const needed_page_tables = @as(usize, @truncate((direct_map_size +| common.PAGE_TABLE_REGION_SIZE -| 1) / common.PAGE_TABLE_REGION_SIZE));

    const needed_page_tables = @as(usize, @truncate((kernel_end_address +| common.PAGE_TABLE_REGION_SIZE -| 1) / common.PAGE_TABLE_REGION_SIZE));

    const directory_entries_allocation_size = @sizeOf(common.PageEntry) * common.ENTRIES_PER_DIRECTORY;
    var kernel_page_directory_entries: common.PageDirectory = @ptrCast(@alignCast(try arch.early_allocator.allocate(directory_entries_allocation_size, common.PAGE_SIZE, arch.ReservedMapRegionType.PERSISTENT)));

    const page_tables_allocation_size = needed_page_tables * @sizeOf(common.PageEntry) * common.ENTRIES_PER_TABLE;
    const direct_map_entries_ptr: *anyopaque = try arch.early_allocator.allocate(page_tables_allocation_size, common.PAGE_SIZE, arch.ReservedMapRegionType.PERSISTENT);
    var direct_map_entries: [][common.ENTRIES_PER_TABLE]common.PageEntry = @as([*][common.ENTRIES_PER_TABLE]common.PageEntry, @ptrCast(@alignCast(direct_map_entries_ptr)))[0..needed_page_tables];

    const ro_data_start = @intFromPtr(&_rodata_start);
    _ = ro_data_start;

    sections = .{
        .{ .start = RESERVED_LOWER_START, .end = RESERVED_LOWER_END, .protection = .{ .write = false, .user = false } },
        .{ .start = VGA_BUFFER_START, .end = VGA_BUFFER_END, .protection = .{ .write = true, .user = false } },
        .{ .start = RESERVED_UPPER_START, .end = RESERVED_UPPER_END, .protection = .{ .write = false, .user = false } },
        .{ .start = @intFromPtr(&_multiboot_header_start), .end = @intFromPtr(&_multiboot_header_end), .protection = .{ .write = false, .user = false } },
        .{ .start = @intFromPtr(&_multiboot_text_start), .end = @intFromPtr(&_multiboot_text_end), .protection = .{ .write = false, .user = false } },
        .{ .start = @intFromPtr(&_multiboot_rodata_start), .end = @intFromPtr(&_multiboot_rodata_end), .protection = .{ .write = false, .user = false } },
        .{ .start = @intFromPtr(&_multiboot_data_start), .end = @intFromPtr(&_multiboot_data_end), .protection = .{ .write = true, .user = false } },
        .{ .start = @intFromPtr(&_multiboot_bss_start), .end = @intFromPtr(&_multiboot_bss_end), .protection = .{ .write = true, .user = false } },
        .{ .start = @intFromPtr(&_text_start), .end = @intFromPtr(&_text_end), .protection = .{ .write = false, .user = false } },
        .{ .start = @intFromPtr(&_rodata_start), .end = @intFromPtr(&_rodata_end), .protection = .{ .write = false, .user = false } },
        .{ .start = @intFromPtr(&_data_start), .end = @intFromPtr(&_data_end), .protection = .{ .write = true, .user = false } },
        .{ .start = @intFromPtr(&_bss_start), .end = @intFromPtr(&_bss_end), .protection = .{ .write = true, .user = false } },
    };

    var current_section: usize = 0;

    var section_size: usize = undefined;
    var section_needed_pages: usize = 0;

    var protections: arch.PageProtection = undefined;

    for (0..needed_page_tables) |directory_index| {
        kernel_page_directory_entries[directory_index].address = @truncate(@intFromPtr(&direct_map_entries[directory_index]) >> 12);
        kernel_page_directory_entries[directory_index].present = true;
        kernel_page_directory_entries[directory_index].writeable = true;
        kernel_page_directory_entries[directory_index].user_accessible = false;

        kernel_page_directory_entries[common.HIGHER_HALF_INDEX + directory_index].address = @truncate(@intFromPtr(&direct_map_entries[directory_index]) >> 12);
        kernel_page_directory_entries[common.HIGHER_HALF_INDEX + directory_index].present = true;
        kernel_page_directory_entries[common.HIGHER_HALF_INDEX + directory_index].writeable = true;
        kernel_page_directory_entries[common.HIGHER_HALF_INDEX + directory_index].user_accessible = false;

        for (0..common.ENTRIES_PER_TABLE) |table_index| {
            protections = .{ .write = true, .user = false };

            while ((section_needed_pages == 0) and (current_section < sections.len)) {
                section_size = sections[current_section].end - sections[current_section].start;

                if (section_size == 0) {
                    current_section += 1;
                    continue;
                }

                section_needed_pages = (section_size + common.PAGE_SIZE -| 1) / common.PAGE_SIZE;
                protections = sections[current_section].protection;
            }

            direct_map_entries[directory_index][table_index].writeable = protections.write;
            direct_map_entries[directory_index][table_index].user_accessible = protections.user;

            direct_map_entries[directory_index][table_index].address = @truncate(((directory_index * common.PAGE_TABLE_REGION_SIZE) + (table_index * common.PAGE_SIZE)) >> 12);
            direct_map_entries[directory_index][table_index].present = true;

            if (current_section < sections.len) {
                section_needed_pages -= 1;
            }

            if (section_needed_pages == 0) {
                current_section += 1;
            }
        }
    }

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
        : [pageDirectoryAddress] "r" (kernel_page_directory_entries),
        : .{ .eax = true, .memory = true });
}

pub fn readMultibootMemoryMap() linksection(".multiboot.text") void {
    var offset: usize = 0;

    for (0..arch.MAX_MEMORY_MAP_ENTRIES) |entry| {
        if (offset >= multiboot.multibootInfo.mmap_length) {
            break;
        }

        const map_entry: *MultibootMemoryMapEntry = @ptrFromInt(multiboot.multibootInfo.mmap_addr + offset);

        memoryMap.entries[entry].address = map_entry.address;
        memoryMap.entries[entry].size = map_entry.length;

        switch (map_entry.region_type) {
            MultibootMemoryMapRegionTypes.AVAILABLE => memoryMap.entries[entry].region_type = arch.MemoryMapRegionType.AVAILABLE,
            MultibootMemoryMapRegionTypes.ACPI_RECLAIMABLE => memoryMap.entries[entry].region_type = arch.MemoryMapRegionType.RECLAIMABLE,
            else => memoryMap.entries[entry].region_type = arch.MemoryMapRegionType.RESERVED,
        }

        memoryMap.length += 1;
        offset += map_entry.size + 4;
    }
}

pub fn getMemoryMap() linksection(".multiboot.text") *arch.MemoryMap {
    if (memoryMap.length == 0) {
        readMultibootMemoryMap();
    }

    if (memoryMap.length == 0) {
        @panic("Couldn't parse memory map!");
    }

    return &memoryMap;
}

pub fn getMaxAvailableAddress() linksection(".multiboot.text") u64 {
    if (memoryMap.length == 0) {
        _ = getMemoryMap();
    }

    if (maxAvailableAddress == 0) {
        for (memoryMap.entries[0..memoryMap.length]) |entry| {
            if (entry.region_type == arch.MemoryMapRegionType.AVAILABLE) {
                maxAvailableAddress = entry.address + entry.size;
            }
        }
    }

    return maxAvailableAddress;
}

pub fn getDirectMapVirtualAddress() linksection(".multiboot.text") u64 {
    return common.DIRECT_MAP_VIRTUAL_ADDRESS;
}

pub fn getDirectMapMaxSize() linksection(".multiboot.text") u64 {
    return common.DIRECT_MAP_SIZE;
}
