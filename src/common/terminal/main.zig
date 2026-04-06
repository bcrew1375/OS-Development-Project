const arch = @import("arch");

pub const print = @import("print.zig");

pub fn initialize() void {
    arch.platform.initializeConsole();
}
