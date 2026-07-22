const arch = @import("../../architecture.zig");

const std = @import("std");

var memoryMap = arch.MemoryMap{};

var testRegion: arch.MemoryMapEntry = undefined;
var testRegionHeap: []u8 = undefined;

var heapBase: usize = 0;

// Track mapped page tables so getPhysicalAddress can distinguish
// "table not present" from "page not present".
const MAX_MOCK_TABLES = 32;
const MockTableMapping = struct {
    virtual_address: usize,
    physical_address: usize,
};
var tableMappings: [MAX_MOCK_TABLES]MockTableMapping = undefined;
var tableMappingCount: usize = 0;

pub fn getPhysicalAddress(virtualAddress: usize) ?usize {
    _ = virtualAddress;
    return null;
}

pub fn isTablePresent(virtualAddress: usize) bool {
    const pageTableRegionSize = getPageTableRegionSize();
    const tableAlignedAddress = virtualAddress & ~(pageTableRegionSize - 1);
    for (tableMappings[0..tableMappingCount]) |mapping| {
        if (mapping.virtual_address == tableAlignedAddress) {
            return true;
        }
    }
    return false;
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
    // Check if this table is already mapped.
    for (tableMappings[0..tableMappingCount]) |*mapping| {
        if (mapping.virtual_address == virtualAddress) {
            return;
        }
    }

    if (tableMappingCount >= MAX_MOCK_TABLES) {
        @panic("Mock MMU: too many page tables");
    }

    tableMappings[tableMappingCount] = .{
        .virtual_address = virtualAddress,
        .physical_address = physicalAddress,
    };
    tableMappingCount += 1;
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

pub fn getPageSize() usize {
    return 4096;
}

pub fn getPageTableRegionSize() usize {
    return 4096 * 1024;
}
