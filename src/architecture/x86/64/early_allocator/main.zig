const arch = @import("arch");
const common_early_allocator = @import("../../../early_allocator.zig");

var reservedMap: arch.ReservedMap = arch.ReservedMap{};

fn linkerAddr(comptime name: [:0]const u8) usize {
    return @intFromPtr(@extern(*const anyopaque, .{ .name = name }));
}

pub fn initialize() arch.EarlyAllocError!void {
    try common_early_allocator.initialize();

    try reserveKernelImageRegions();
}

fn reserveKernelImageRegions() arch.EarlyAllocError!void {
    try reserveLinkerRange("_text_start", "_text_end", arch.ReservedMapRegionType.KERNEL_READ_ONLY);
    try reserveLinkerRange("_rodata_start", "_rodata_end", arch.ReservedMapRegionType.KERNEL_READ_ONLY);
    try reserveLinkerRange("_data_start", "_data_end", arch.ReservedMapRegionType.KERNEL_WRITABLE);
    try reserveLinkerRange("_bss_start", "_bss_end", arch.ReservedMapRegionType.KERNEL_WRITABLE);
}

fn reserveLinkerRange(
    comptime start_name: [:0]const u8,
    comptime end_name: [:0]const u8,
    region_type: arch.ReservedMapRegionType,
) arch.EarlyAllocError!void {
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

pub fn allocate(neededSize: usize, alignment: usize, entryType: arch.ReservedMapRegionType) arch.EarlyAllocError!*allowzero anyopaque {
    return try common_early_allocator.allocate(neededSize, alignment, entryType);
}

pub fn reserve(address: usize, size: usize, entry_type: arch.ReservedMapRegionType) arch.EarlyAllocError!void {
    try common_early_allocator.reserve(address, size, entry_type);
}

pub fn getReservedMap() *arch.ReservedMap {
    return &reservedMap;
}
