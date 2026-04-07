pub fn initialize() callconv(.c) void {}
pub fn getPhysicalAddress(virtualAddress: usize) ?usize {
    _ = virtualAddress;
}
pub fn removeIdentityMapping() void {}
