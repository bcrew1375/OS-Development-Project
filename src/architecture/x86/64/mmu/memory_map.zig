const arch = @import("arch");
const limine_protocol = @import("../../common/boot/limine/protocol.zig");
const limine_requests = @import("../../common/boot/limine/requests.zig");

var memoryMap: arch.MemoryMap = arch.MemoryMap{};
var maxAvailableAddress: u64 = 0;

pub fn readLimineMemoryMap() void {
    const response = limine_requests.memoryMapResponse() orelse return;
    const entry_count = @min(@as(usize, @intCast(response.entry_count)), arch.MAX_MEMORY_MAP_ENTRIES);

    for (0..entry_count) |entry_index| {
        memoryMap.entries[entry_index] = convertLimineMemoryMapEntry(response.entries[entry_index].*);
        memoryMap.length += 1;
    }
}

fn convertLimineMemoryMapEntry(entry: limine_protocol.MemoryMapEntry) arch.MemoryMapEntry {
    return .{
        .address = entry.base,
        .size = entry.length,
        .region_type = convertLimineMemoryMapEntryType(entry.entry_type),
    };
}

fn convertLimineMemoryMapEntryType(
    entry_type: limine_protocol.MemoryMapEntryType,
) arch.MemoryMapRegionType {
    return switch (entry_type) {
        .USABLE => .AVAILABLE,
        .BOOTLOADER_RECLAIMABLE, .ACPI_RECLAIMABLE => .RECLAIMABLE,
        .BAD_MEMORY => .BAD,
        else => .RESERVED,
    };
}

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
