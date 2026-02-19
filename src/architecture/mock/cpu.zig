const cpu = @import("../architecture.zig").Arch.Cpu;

pub fn Cpu() cpu {
    return cpu{
        .unrecoverableHalt = struct {
            fn unrecoverableHalt() noreturn {}
        }.unrecoverableHalt,
    };
}
