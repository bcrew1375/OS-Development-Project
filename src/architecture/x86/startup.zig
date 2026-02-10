const arch = @import("../architecture.zig").Arch.Startup;

const startup = @import("startup/main.zig");

pub fn Startup() arch {
    return arch{
        .finishStartup = startup.finishStartup,
    };
}
