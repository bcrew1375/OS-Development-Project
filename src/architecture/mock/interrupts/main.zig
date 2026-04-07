pub fn initialize() void {}
pub fn set(interruptVector: usize, address: usize, typeAttribute: usize) void {
    _ = interruptVector;
    _ = address;
    _ = typeAttribute;
}
pub fn enableInterrupts() void {}
pub fn disableInterrupts() void {}
pub fn acknowledgeInterrupt(vector: usize) void {
    _ = vector;
}
