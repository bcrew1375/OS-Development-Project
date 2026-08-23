const arch = @import("arch");
const common_early_allocator = @import("../../../early_allocator.zig");
const mmu_common = @import("../mmu/common.zig");

var reservedMap: arch.ReservedMap linksection(".multiboot.data") = arch.ReservedMap{};

/// Resolves a linker-defined symbol's address by name, without needing a
/// dedicated `extern const` declaration for every symbol in the file.
fn linkerAddr(comptime name: [:0]const u8) linksection(".multiboot.text") usize {
    return @intFromPtr(@extern(*const anyopaque, .{ .name = name }));
}

const RESERVED_LOWER_START: usize = 0x00000000;
const RESERVED_LOWER_END: usize = 0x000B8000;

const VGA_BUFFER_START = 0x000B8000;
const VGA_BUFFER_END = VGA_BUFFER_START + 0x8000;

const RESERVED_UPPER_START: usize = 0x000C0000;
const RESERVED_UPPER_END: usize = 0x00100000;

pub fn initialize() linksection(".multiboot.text") arch.EarlyAllocError!void {
    try common_early_allocator.initialize();

    try reserveLegacyRegions();
    try reserveKernelImageRegions();
}

fn reserveLegacyRegions() linksection(".multiboot.text") arch.EarlyAllocError!void {
    try arch.early_allocator.reserve(
        RESERVED_LOWER_START,
        RESERVED_LOWER_END - RESERVED_LOWER_START,
        arch.ReservedMapRegionType.PERSISTENT,
    );
    try arch.early_allocator.reserve(
        VGA_BUFFER_START,
        VGA_BUFFER_END - VGA_BUFFER_START,
        arch.ReservedMapRegionType.DEVICE_MEMORY,
    );
    try arch.early_allocator.reserve(
        RESERVED_UPPER_START,
        RESERVED_UPPER_END - RESERVED_UPPER_START,
        arch.ReservedMapRegionType.PERSISTENT,
    );
}

fn reserveKernelImageRegions() linksection(".multiboot.text") arch.EarlyAllocError!void {
    try reserveLinkerRange("_multiboot_header_start", "_multiboot_header_end", arch.ReservedMapRegionType.KERNEL_READ_ONLY);
    try reserveLinkerRange("_multiboot_text_start", "_multiboot_text_end", arch.ReservedMapRegionType.KERNEL_READ_ONLY);
    try reserveLinkerRange("_multiboot_rodata_start", "_multiboot_rodata_end", arch.ReservedMapRegionType.KERNEL_READ_ONLY);
    try reserveLinkerRange("_multiboot_data_start", "_multiboot_data_end", arch.ReservedMapRegionType.KERNEL_WRITABLE);
    try reserveLinkerRange("_multiboot_bss_start", "_multiboot_bss_end", arch.ReservedMapRegionType.KERNEL_WRITABLE);
    try reserveLinkerRange("_text_start", "_text_end", arch.ReservedMapRegionType.KERNEL_READ_ONLY);
    try reserveLinkerRange("_rodata_start", "_rodata_end", arch.ReservedMapRegionType.KERNEL_READ_ONLY);
    try reserveLinkerRange("_data_start", "_data_end", arch.ReservedMapRegionType.KERNEL_WRITABLE);
    try reserveLinkerRange("_bss_start", "_bss_end", arch.ReservedMapRegionType.KERNEL_WRITABLE);
}

fn reserveLinkerRange(
    comptime start_name: [:0]const u8,
    comptime end_name: [:0]const u8,
    region_type: arch.ReservedMapRegionType,
) linksection(".multiboot.text") arch.EarlyAllocError!void {
    const start_address = linkerAddr(start_name);
    const end_address = linkerAddr(end_name);

    if (end_address < start_address) {
        return arch.EarlyAllocError.InvalidMemoryMap;
    }

    if (end_address == start_address) {
        return;
    }

    try arch.early_allocator.reserve(start_address, end_address - start_address, region_type);
}

pub fn allocate(neededSize: usize, alignment: usize, entryType: arch.ReservedMapRegionType) linksection(".multiboot.text") arch.EarlyAllocError!*allowzero anyopaque {
    return try common_early_allocator.allocate(neededSize, alignment, entryType);
}

pub fn reserve(address: usize, size: usize, entry_type: arch.ReservedMapRegionType) linksection(".multiboot.text") arch.EarlyAllocError!void {
    try common_early_allocator.reserve(address, size, entry_type);
}

pub fn getReservedMap() linksection(".multiboot.text") *arch.ReservedMap {
    return &reservedMap;
}
