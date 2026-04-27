const arch = @import("arch");
const common_early_allocator = @import("../../early_allocator.zig");

const mmu = @import("../mmu/main.zig");

var reservedMap: arch.ReservedMap linksection(".multiboot.data") = arch.ReservedMap{};

pub fn initialize() arch.EarlyAllocError!void {
    try common_early_allocator.initialize();
}

pub fn allocate(neededSize: usize, alignment: usize, entryType: arch.ReservedMapEntryType) arch.EarlyAllocError!*allowzero anyopaque {
    return try common_early_allocator.allocate(neededSize, alignment, entryType);
}

pub fn reserve(address: usize, size: usize, entry_type: arch.ReservedMapEntryType) arch.EarlyAllocError!void {
    try common_early_allocator.reserve(address, size, entry_type);
}

pub fn getReservedMap() linksection(".multiboot.text") *arch.ReservedMap {
    return &reservedMap;
}
