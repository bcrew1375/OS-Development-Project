const interrupts = @import("../architecture.zig").Arch.Interrupts;

pub fn Interrupts() interrupts {
    return interrupts{
        .initialize = struct {
            fn initialize() void {}
        }.initialize,

        .set = struct {
            fn set(interrupt_number: usize, address: usize, type_attribute: usize) void {
                _ = interrupt_number;
                _ = address;
                _ = type_attribute;
            }
        }.set,

        .enableInterrupts = struct {
            fn enableInterrupts() void {}
        }.enableInterrupts,

        .disableInterrupts = struct {
            fn disableInterrupts() void {}
        }.disableInterrupts,

        .acknowledgeInterrupt = struct {
            fn acknowledgeInterrupt(vector: usize) void {
                _ = vector;
            }
        }.acknowledgeInterrupt,
    };
}
