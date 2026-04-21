const arch = @import("arch");

const std = @import("std");

var reservedMap linksection(".multiboot.data") = arch.ReservedMap{};
var memoryMap: *arch.MemoryMap linksection(".multiboot.data") = undefined;

extern const _kernel_start: anyopaque;
extern const _kernel_end: anyopaque;

pub fn initialize() linksection(".multiboot.text") void {
    memoryMap = arch.mmu.getMemoryMap();

    const kernel_start_address = @intFromPtr(&_kernel_start);
    const kernel_end_address = @intFromPtr(&_kernel_end);

    for (memoryMap.entries[0..memoryMap.length]) |entry| {
        if (entry.region_type != arch.MemoryMapEntryType.AVAILABLE) {
            reserve(@truncate(entry.address), @truncate(entry.size), arch.ReservedMapEntryType.PERSISTENT);
        }
    }

    reserve(0, 1048576, arch.ReservedMapEntryType.PERSISTENT);
    reserve(kernel_start_address, kernel_end_address - kernel_start_address, arch.ReservedMapEntryType.PERSISTENT);
}

pub fn allocate(neededSize: usize, alignment: usize, entryType: arch.ReservedMapEntryType) linksection(".multiboot.text") *anyopaque {
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
            reserve(candidate_start, candidate_end - candidate_start, entryType);
            return @ptrFromInt(candidate_start);
        }
    }

    arch.platform.writer.print("Early allocation failed with error {s}", .{@errorName(arch.EarlyAllocError.OutOfSpace)}) catch {};
    arch.cpu.unrecoverableHalt();
}

fn reserve(address: usize, size: usize, entry_type: arch.ReservedMapEntryType) linksection(".multiboot.text") void {
    if (reservedMap.length >= arch.MAX_EARLY_RESERVATIONS) {
        arch.platform.writer.print("Early allocation failed with error: {s}", .{@errorName(arch.EarlyAllocError.OutOfReservations)}) catch {};
        arch.cpu.unrecoverableHalt();
    }

    reservedMap.entries[reservedMap.length].address = address;
    reservedMap.entries[reservedMap.length].size = size;
    reservedMap.entries[reservedMap.length].entry_type = entry_type;

    reservedMap.length += 1;
}
