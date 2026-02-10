const arch = @import("../architecture.zig").Arch.Time;

const time = @import("time/main.zig");

pub fn Time() arch {
    return arch{
        .setupTimer = time.setupTimer,
    };
}
