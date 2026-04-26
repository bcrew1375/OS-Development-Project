const std = @import("std");
const arch = @import("arch");

const mmu = @import("../mmu/main.zig");

var reservedMap linksection(".multiboot.data") = arch.ReservedMap{};
var memoryMap: *arch.MemoryMap linksection(".multiboot.data") = undefined;

pub fn initialize() !void {}

pub fn allocate(neededSize: usize, alignment: usize, entryType: arch.ReservedMapEntryType) arch.EarlyAllocError!*anyopaque {
    if (neededSize == 0) {
        return arch.EarlyAllocError.InvalidSize;
    }

    if (alignment == 0) {
        return arch.EarlyAllocError.InvalidAlignment;
    }

    memoryMap = mmu.getMemoryMap() catch {
        return arch.EarlyAllocError.InvalidMemoryMap;
    };

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
            _ = entryType;
            //try reserve(candidate_start, neededSize, entryType);
            return @ptrFromInt(candidate_start);
        }
    }

    return arch.EarlyAllocError.OutOfSpace;
}

pub fn finishBoot() void {}
