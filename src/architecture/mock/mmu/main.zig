const std = @import("std");
const arch = @import("arch");

var memoryMap: *arch.MemoryMap = undefined;

var regionsMap: [arch.MAX_MEMORY_MAP_ENTRIES]arch.MemoryMapEntry = [_]arch.MemoryMapEntry{.{}} ** arch.MAX_MEMORY_MAP_ENTRIES;

var testRegion: arch.MemoryMapEntry = undefined;
var testRegionHeap: []u8 = undefined;

pub fn getPhysicalAddress(virtualAddress: usize) ?usize {
    _ = virtualAddress;
}
pub fn removeIdentityMapping() void {}
pub fn getMemoryMap() arch.MmuError!*arch.MemoryMap {
    testRegionHeap = std.heap.page_allocator.alloc(u8, 64 * 1024 * 1024) catch {
        return arch.MmuError.MemoryMapReadError;
    };

    testRegion.address = @intFromPtr(testRegionHeap.ptr);
    testRegion.region_type = arch.MemoryMapEntryType.AVAILABLE;
    testRegion.size = 64 * 1024 * 1024;

    regionsMap[0] = testRegion;

    memoryMap = std.heap.page_allocator.create(arch.MemoryMap) catch {
        return arch.MmuError.MemoryMapReadError;
    };

    memoryMap.entries = &regionsMap;
    memoryMap.length = 1;

    return memoryMap;
}

pub fn mapPage(virtual_address: usize, physical_address: usize) void {
    _ = virtual_address;
    _ = physical_address;
}

pub fn unmapPage(virtual_address: usize) void {
    _ = virtual_address;
}
