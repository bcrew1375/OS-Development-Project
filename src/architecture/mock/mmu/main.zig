const arch = @import("../../architecture.zig");

const std = @import("std");

var memoryMap = arch.MemoryMap{};

var testRegion: arch.MemoryMapEntry = undefined;
var testRegionHeap: []u8 = undefined;

var heapBase: usize = 0;

pub fn getPhysicalAddress(virtualAddress: usize) ?usize {
    _ = virtualAddress;
    return null;
}

pub fn getMemoryMap() *arch.MemoryMap {
    testRegionHeap = std.heap.page_allocator.alloc(u8, 64 * 1024 * 1024) catch {
        @panic("Mock MMU allocation failed");
    };
    testRegion.address = @intFromPtr(testRegionHeap.ptr);
    testRegion.region_type = arch.MemoryMapRegionType.AVAILABLE;
    testRegion.size = 64 * 1024 * 1024;

    heapBase = @intFromPtr(testRegionHeap.ptr);

    memoryMap.entries[0] = testRegion;
    memoryMap.length = 1;

    return &memoryMap;
}

pub fn mapPage(virtualAddress: usize, physicalAddress: usize, flags: arch.PageProtection) arch.MmuError!void {
    _ = virtualAddress;
    _ = physicalAddress;
    _ = flags;
}

pub fn mapTable(virtualAddress: usize, physicalAddress: usize) arch.MmuError!void {
    _ = virtualAddress;
    _ = physicalAddress;
}

pub fn unmapPage(virtualAddress: usize) void {
    _ = virtualAddress;
}

pub fn getMaxAvailableAddress() u64 {
    return testRegion.size;
}

pub fn getDirectMapVirtualAddress() u64 {
    return 0;
}

pub fn getDirectMapMaxSize() u64 {
    return 0;
}

pub fn getKernelHeapVirtualAddress() u64 {
    return 0;
}

pub fn getKernelHeapSize() u64 {
    return 0;
}
