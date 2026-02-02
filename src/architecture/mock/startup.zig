const startup = @import("../architecture.zig").Arch.Startup;

pub fn Startup() startup {
    return startup{
        .finishStartup = struct {
            fn finishStartup() void {}
        }.finishStartup,
    };
}
