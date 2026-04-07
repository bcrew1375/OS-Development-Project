const TextColor = @import("arch").TextColor;

const std = @import("std");

pub fn initializeConsole() void {}
pub fn initializeTimer(frequency: usize) void {
    _ = frequency;
}

pub fn setColor(color: TextColor) void {
    _ = color;
}

pub const Writer = std.io.GenericWriter(void, error{}, struct {
    fn write(_: void, bytes: []const u8) error{}!usize {
        std.debug.print("{s}", .{bytes});
        return bytes.len;
    }
}.write);

pub const writer = Writer{ .context = {} };
