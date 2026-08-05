const arch = @import("arch");
const common_early_allocator = @import("../../early_allocator.zig");

const mmu = @import("../mmu/early_boot.zig");

const PAGE_SIZE = @import("../mmu/common.zig").PAGE_SIZE;
const ENTRIES_PER_TABLE = @import("../mmu/common.zig").ENTRIES_PER_TABLE;

var reservedMap: arch.ReservedMap linksection(".multiboot.data") = arch.ReservedMap{};

extern const _kernel_start: usize;
extern const _kernel_end: usize;

pub fn initialize() linksection(".multiboot.text") arch.EarlyAllocError!void {
    try common_early_allocator.initialize();

    // Reserve legacy x86 regions.
    arch.early_allocator.reserve(0, 0x100000, arch.ReservedMapRegionType.PERSISTENT) catch |err| {
        @panic(@errorName(err));
    };

    const kernel_start_address = @intFromPtr(&_kernel_start);
    const kernel_end_address = @intFromPtr(&_kernel_end);

    arch.early_allocator.reserve(kernel_start_address, kernel_end_address - kernel_start_address, arch.ReservedMapRegionType.KERNEL_CODE) catch |err| {
        @panic(@errorName(err));
    };
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
