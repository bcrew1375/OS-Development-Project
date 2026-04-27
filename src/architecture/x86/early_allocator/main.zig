const arch = @import("arch");
const common_early_allocator = @import("../../early_allocator.zig");

const mmu = @import("../mmu/main.zig");

var reservedMap: arch.ReservedMap linksection(".multiboot.data") = arch.ReservedMap{};
var remainingPageSpace: usize linksection(".multiboot.data") = mmu.PAGE_TABLE_REGION_SIZE;
var nextTableAddressSpace: usize linksection(".multiboot.data") = mmu.PAGE_TABLE_REGION_SIZE;

extern const _kernel_start: usize;
extern const _kernel_end: usize;

pub fn initialize() linksection(".multiboot.text") arch.EarlyAllocError!void {
    try common_early_allocator.initialize();

    // Reserve legacy x86 regions.
    arch.early_allocator.reserve(0, 0x9FC00, arch.ReservedMapEntryType.PERSISTENT) catch |err| {
        @panic(@errorName(err));
    };
    arch.early_allocator.reserve(0xA0000, 0x50000, arch.ReservedMapEntryType.PERSISTENT) catch |err| {
        @panic(@errorName(err));
    };

    const kernel_start_address = @intFromPtr(&_kernel_start);
    const kernel_end_address = @intFromPtr(&_kernel_end);

    arch.early_allocator.reserve(kernel_start_address, kernel_end_address - kernel_start_address, arch.ReservedMapEntryType.PERSISTENT) catch |err| {
        @panic(@errorName(err));
    };
}

pub fn allocate(neededSize: usize, alignment: usize, entryType: arch.ReservedMapEntryType) linksection(".multiboot.text") arch.EarlyAllocError!*allowzero anyopaque {
    return try common_early_allocator.allocate(neededSize, alignment, entryType);
}

pub fn reserve(address: usize, size: usize, entry_type: arch.ReservedMapEntryType) linksection(".multiboot.text") arch.EarlyAllocError!void {
    try common_early_allocator.reserve(address, size, entry_type);

    if (size > remainingPageSpace) {
        const page_table_count: usize = @truncate((size / mmu.PAGE_TABLE_REGION_SIZE) +| 1);
        try expandPageTables(page_table_count);
        remainingPageSpace +|= mmu.PAGE_TABLE_REGION_SIZE * page_table_count;
    }

    remainingPageSpace -|= size;
}

pub fn getReservedMap() linksection(".multiboot.text") *arch.ReservedMap {
    return &reservedMap;
}

fn expandPageTables(pageTables: usize) linksection(".multiboot.text") arch.EarlyAllocError!void {
    if (pageTables == 0) {
        return arch.EarlyAllocError.InvalidSize;
    }

    const start_address = @intFromPtr(try allocate(pageTables, mmu.PAGE_SIZE, arch.ReservedMapEntryType.PERSISTENT));

    for (0..pageTables) |_| {
        mmu.mapEarlyPageTable(start_address, nextTableAddressSpace);
        nextTableAddressSpace += mmu.PAGE_TABLE_REGION_SIZE;
    }
}
