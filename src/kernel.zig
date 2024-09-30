const kernel_common = @import("lib/kernel_common.zig");
const terminal = @import("lib/terminal.zig");

pub const MESSAGE = "Aello,\nWorld!";

pub export fn kernelMain() void {
    kernel_common.kernelInitialize();
    terminal.initialize();

    terminal.print(MESSAGE);
}
