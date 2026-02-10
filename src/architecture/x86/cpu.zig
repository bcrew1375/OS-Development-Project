const arch = @import("../architecture.zig").Arch.Cpu;

const cpu = @import("cpu/main.zig");

pub fn Cpu() arch {
    return arch{
        .unrecoverableHalt = cpu.unrecoverableHalt,
    };
}
