const interrupts = @import("../architecture.zig").Arch.Interrupts;

pub fn Interrupts() interrupts {
    return interrupts{
        .initialize = struct {
            fn initialize() void {}
        },

        .set = struct {
            fn set() void {}
        }.set,

        .enableInterrupts = struct {
            fn enableInterrupts() void {}
        }.enableInterrupts,

        .disableInterrupts = struct {
            fn disableInterrupts() void {}
        }.disableInterrupts,

        .acknowledgeInterrupt = struct {
            fn acknowledgeInterrupt() void {}
        }.acknowledgeInterrupt,
    };
}
