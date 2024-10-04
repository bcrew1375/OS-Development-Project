const kernel_common = @import("lib/kernel_common.zig");
const terminal = @import("lib/terminal.zig");
const portio = @import("lib/port-io.zig");

pub const MESSAGE = "Aello,World!\n";

pub export fn kernelMain() void {
    kernel_common.kernelInitialize();
    terminal.initialize();
    terminal.print(MESSAGE);
}
