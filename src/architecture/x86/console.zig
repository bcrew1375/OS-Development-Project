const arch = @import("../architecture.zig").Arch.Console;

const console = @import("console/main.zig");

pub fn Console() arch {
    return arch{
        .initialize = console.initialize,
        .print = console.print,
        .printLog = console.printLog,
    };
}
