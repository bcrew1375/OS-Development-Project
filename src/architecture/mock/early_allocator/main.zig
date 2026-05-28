const arch = @import("../../architecture.zig");

var mock_reserved_map = arch.ReservedMap{};

pub fn initialize() arch.EarlyAllocError!void {}

pub fn allocate(needed_size: usize, alignment: usize, region_type: arch.ReservedMapRegionType) arch.EarlyAllocError!*allowzero anyopaque {
    _ = needed_size;
    _ = alignment;
    _ = region_type;
    return @ptrFromInt(0);
}

pub fn reserve(address: usize, size: usize, region_type: arch.ReservedMapRegionType) arch.EarlyAllocError!void {
    _ = address;
    _ = size;
    _ = region_type;
}

pub fn getReservedMap() *arch.ReservedMap {
    return &mock_reserved_map;
}
