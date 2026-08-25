const limine = @import("../boot/limine/main.zig");

const arch = @import("arch");

var memoryMap: arch.MemoryMap = arch.MemoryMap{};
var maxAvailableAddress: u64 = 0;

pub fn readLimineMemoryMap() void {
    const response = limine.memory_map_request.response orelse return;
    const entry_count = @min(@as(usize, @intCast(response.entry_count)), arch.MAX_MEMORY_MAP_ENTRIES);

    for (0..entry_count) |entry| {
        const map_entry = response.entries[entry];

        memoryMap.entries[entry].address = map_entry.base;
        memoryMap.entries[entry].size = map_entry.length;

        switch (map_entry.entry_type) {
            limine.MemoryMapEntryType.USABLE => memoryMap.entries[entry].region_type = arch.MemoryMapRegionType.AVAILABLE,
            limine.MemoryMapEntryType.BOOTLOADER_RECLAIMABLE,
            limine.MemoryMapEntryType.ACPI_RECLAIMABLE,
            => memoryMap.entries[entry].region_type = arch.MemoryMapRegionType.RECLAIMABLE,
            else => memoryMap.entries[entry].region_type = arch.MemoryMapRegionType.RESERVED,
        }

        memoryMap.length += 1;
    }
}

/// Centralizes the lazy-load check that both `getMemoryMap` and
/// `getMaxAvailableAddress` previously duplicated independently. One
/// place now owns "has the map been read yet" - if that condition
/// ever needs to change (e.g. to a real `bool` flag instead of
/// `length == 0`), it changes in exactly one place instead of two.
fn ensureMemoryMapLoaded() void {
    if (memoryMap.length == 0) {
        readLimineMemoryMap();
    }
}

pub fn getMemoryMap() *arch.MemoryMap {
    ensureMemoryMapLoaded();

    if (memoryMap.length == 0) {
        @panic("Couldn't parse memory map!");
    }

    return &memoryMap;
}

pub fn getMaxAvailableAddress() u64 {
    ensureMemoryMapLoaded();

    if (maxAvailableAddress == 0) {
        for (memoryMap.entries[0..memoryMap.length]) |entry| {
            if (entry.region_type == arch.MemoryMapRegionType.AVAILABLE) {
                maxAvailableAddress = @max(maxAvailableAddress, entry.address + entry.size);
            }
        }
    }

    return maxAvailableAddress;
}
