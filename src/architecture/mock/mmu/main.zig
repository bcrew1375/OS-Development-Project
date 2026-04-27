const std = @import("std");
const arch = @import("arch");

var memoryMap: *arch.MemoryMap = undefined;

var regionsMap: [arch.MAX_MEMORY_MAP_ENTRIES]arch.MemoryMapEntry = [_]arch.MemoryMapEntry{.{}} ** arch.MAX_MEMORY_MAP_ENTRIES;

var testRegion: arch.MemoryMapEntry = undefined;
var testRegionHeap: []u8 = undefined;

var heapBase: usize = 0;

pub fn getPhysicalAddress(virtualAddress: usize) ?usize {
    _ = virtualAddress;
}
pub fn removeIdentityMapping() void {}

pub fn getMemoryMap() *arch.MemoryMap {
    testRegionHeap = std.heap.page_allocator.alloc(u8, 64 * 1024 * 1024) catch {
        @panic("Mock MMU allocation failed");
    };
    testRegion.address = @intFromPtr(testRegionHeap.ptr);
    testRegion.region_type = arch.MemoryMapEntryType.AVAILABLE;
    testRegion.size = 64 * 1024 * 1024;

    heapBase = @intFromPtr(testRegionHeap.ptr);

    regionsMap[0] = testRegion;

    memoryMap = std.heap.page_allocator.create(arch.MemoryMap) catch {
        @panic("Mock MMU map creation failed");
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

pub fn getMaxAvailableAddress() u64 {
    return testRegion.size;
}
