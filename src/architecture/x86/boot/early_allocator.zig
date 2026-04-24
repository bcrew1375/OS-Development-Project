const arch = @import("arch");
const mmu = @import("../mmu/main.zig");

const std = @import("std");

var reservedMap linksection(".multiboot.data") = arch.ReservedMap{};
var memoryMap: *arch.MemoryMap linksection(".multiboot.data") = undefined;
var remainingPageSpace: usize linksection(".multiboot.data") = mmu.PAGE_TABLE_REGION_SIZE;
var nextTableAddressSpace: usize linksection(".multiboot.data") = mmu.PAGE_TABLE_REGION_SIZE;

extern const _kernel_start: anyopaque;
extern const _kernel_end: anyopaque;

pub fn initialize() linksection(".multiboot.text") arch.EarlyAllocError!void {
    memoryMap = arch.mmu.getMemoryMap();

    const kernel_start_address = @intFromPtr(&_kernel_start);
    const kernel_end_address = @intFromPtr(&_kernel_end);

    for (memoryMap.entries[0..memoryMap.length]) |entry| {
        if (entry.region_type != arch.MemoryMapEntryType.AVAILABLE) {
            try reserve(@truncate(entry.address), @truncate(entry.size), arch.ReservedMapEntryType.PERSISTENT);
        }
    }

    // Reserve legacy x86 regions.
    try reserve(0, 0x9FC00, arch.ReservedMapEntryType.PERSISTENT);
    try reserve(0xA0000, 0x50000, arch.ReservedMapEntryType.PERSISTENT);

    try reserve(kernel_start_address, kernel_end_address - kernel_start_address, arch.ReservedMapEntryType.PERSISTENT);
}

pub fn allocate(neededSize: usize, alignment: usize, entryType: arch.ReservedMapEntryType) linksection(".multiboot.text") arch.EarlyAllocError!*anyopaque {
    if (neededSize == 0) {
        return arch.EarlyAllocError.InvalidSize;
    }

    if (alignment == 0) {
        return arch.EarlyAllocError.InvalidAlignment;
    }

    for (memoryMap.entries[0..memoryMap.length]) |region| {
        if (region.region_type != arch.MemoryMapEntryType.AVAILABLE) {
            continue;
        }

        const region_start: usize = @truncate(region.address);
        const region_end: usize = region_start + @as(usize, @truncate(region.size)) - 1;

        // Initial candidate address must be within the region and aligned
        var candidate_start: usize = (region_start +| (alignment - 1)) & ~(alignment - 1);

        find_gap: while (true) {
            const candidate_end = candidate_start +| (neededSize - 1);

            // Check if the current candidate still fits inside the available memory region
            if (candidate_end > region_end or candidate_start > region_end) {
                break :find_gap;
            }

            for (reservedMap.entries[0..reservedMap.length]) |reserved| {
                const reserved_start = reserved.address;
                const reserved_end = reserved_start +| (reserved.size - 1);

                if (candidate_start <= reserved_end and candidate_end >= reserved_start) {
                    // Conflict found: bump start address past the reserved region and re-align
                    candidate_start = (reserved_end +| 1 + (alignment - 1)) & ~(alignment - 1);
                    continue :find_gap;
                }
            }

            // If we reached here, no overlaps were found for this candidate
            try reserve(candidate_start, neededSize, entryType);
            return @ptrFromInt(candidate_start);
        }
    }

    return arch.EarlyAllocError.OutOfSpace;
}

fn reserve(address: usize, size: usize, entry_type: arch.ReservedMapEntryType) linksection(".multiboot.text") arch.EarlyAllocError!void {
    if (reservedMap.length >= arch.MAX_EARLY_RESERVATIONS) {
        return arch.EarlyAllocError.OutOfReservations;
    }

    reservedMap.entries[reservedMap.length].address = address;
    reservedMap.entries[reservedMap.length].size = size;
    reservedMap.entries[reservedMap.length].entry_type = entry_type;

    reservedMap.length += 1;

    // // Ensure there's always room left for a new page table.
    // if ((remainingPageSpace -| size) < mmu.PAGE_SIZE) {
    //     try expandPageTables(1);
    // }

    if (size > remainingPageSpace) {
        const page_table_count: usize = @truncate((size / mmu.PAGE_TABLE_REGION_SIZE) +| 1);
        try expandPageTables(page_table_count);
    }

    remainingPageSpace -= size;
}

fn expandPageTables(pageTables: usize) arch.EarlyAllocError!void {
    if (pageTables == 0) {
        return arch.EarlyAllocError.InvalidSize;
    }

    const start_address = @intFromPtr(try allocate(pageTables, mmu.PAGE_SIZE, arch.ReservedMapEntryType.PERSISTENT));

    for (0..pageTables) |page_table| {
        nextTableAddressSpace += page_table * mmu.PAGE_TABLE_REGION_SIZE;
        mmu.mapEarlyPageTable(start_address, nextTableAddressSpace);
    }
}
