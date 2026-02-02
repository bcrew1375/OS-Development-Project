const cpu = @import("../architecture.zig").Arch.Cpu;

pub fn Cpu() cpu {
    return cpu{
        .setupTimer = struct {
            fn setupTimer() void {}
        }.setupTimer,

        .unrecoverableHalt = struct {
            fn unrecoverableHalt() noreturn {}
        }.unrecoverableHalt,
    };
}
