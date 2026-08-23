const arch = @import("arch");

const std = @import("std");

pub inline fn initialize() arch.EarlyAllocError!void {
    const memoryMap = arch.mmu.getMemoryMap();

    for (memoryMap.entries[0..memoryMap.length]) |*entry| {
        if (entry.region_type != arch.MemoryMapRegionType.AVAILABLE) {
            try arch.early_allocator.reserve(@truncate(entry.address), @truncate(entry.size), arch.ReservedMapRegionType.PERSISTENT);
        }
    }
}

pub inline fn allocate(neededSize: usize, alignment: usize, regionType: arch.ReservedMapRegionType) arch.EarlyAllocError!*allowzero anyopaque {
    if (neededSize == 0) {
        return arch.EarlyAllocError.InvalidSize;
    }

    if (alignment == 0) {
        return arch.EarlyAllocError.InvalidAlignment;
    }

    const memoryMap = arch.mmu.getMemoryMap();
    const reservedMap = arch.early_allocator.getReservedMap();

    for (memoryMap.entries[0..memoryMap.length]) |*region| {
        if (region.region_type != arch.MemoryMapRegionType.AVAILABLE) {
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

            for (reservedMap.entries[0..reservedMap.length]) |*reserved| {
                const reserved_start = reserved.address;
                const reserved_end = reserved_start +| (reserved.size - 1);

                if (candidate_start <= reserved_end and candidate_end >= reserved_start) {
                    // Conflict found: bump start address past the reserved region and re-align
                    candidate_start = (reserved_end +| 1 + (alignment - 1)) & ~(alignment - 1);
                    continue :find_gap;
                }
            }

            // If we reached here, no overlaps were found for this candidate
            try arch.early_allocator.reserve(candidate_start, neededSize, regionType);
            return @ptrFromInt(candidate_start);
        }
    }

    return arch.EarlyAllocError.OutOfSpace;
}

pub inline fn reserve(address: usize, size: usize, region_type: arch.ReservedMapRegionType) arch.EarlyAllocError!void {
    const reservedMap = arch.early_allocator.getReservedMap();

    if (reservedMap.length >= arch.MAX_EARLY_RESERVATIONS) {
        return arch.EarlyAllocError.OutOfReservations;
    }

    reservedMap.entries[reservedMap.length].address = address;
    reservedMap.entries[reservedMap.length].size = size;
    reservedMap.entries[reservedMap.length].region_type = region_type;

    reservedMap.length += 1;
}
