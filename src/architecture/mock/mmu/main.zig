const arch = @import("arch");

pub fn initialize() callconv(.c) void {}
pub fn getPhysicalAddress(virtualAddress: usize) ?usize {
    _ = virtualAddress;
}
pub fn removeIdentityMapping() void {}
pub fn initializeMemoryMap() void {}
pub fn getMemoryMap() *arch.MemoryMap {
    var memoryMap = arch.MemoryMap{};

    memoryMap.entries[0].address = 0;
    memoryMap.entries[0].length = 64 * 1024 * 1024;
    memoryMap.entries[0].available = true;

    memoryMap.length = 1;

    return &memoryMap;
}
