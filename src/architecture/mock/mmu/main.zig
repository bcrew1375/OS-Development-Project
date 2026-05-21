const arch = @import("../../architecture.zig");

var mock_memory_map = arch.MemoryMap{};

pub fn getPhysicalAddress(virtualAddress: usize) ?usize {
    _ = virtualAddress;
    return null;
}

pub fn getMemoryMap() *arch.MemoryMap {
    return &mock_memory_map;
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
    return 0;
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
