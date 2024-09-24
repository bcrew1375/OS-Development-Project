const kernel_common = @import("lib/kernel_common.zig");
const terminal = @import("lib/terminal.zig");

pub const MESSAGE = "Aello, World!";

pub export fn kernel_main() void {
    kernel_common.kernel_initialize();
    terminal.initialize();

    terminal.print(MESSAGE);
}

pub fn print(string: []const u8) void {
    _ = string;
}

fn make_char(character: u8, color: u8) u16 {
    return (@as(u16, color) << 8) | character;
}
