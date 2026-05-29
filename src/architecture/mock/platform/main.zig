const arch = @import("../../architecture.zig");
const std = @import("std");

pub fn initializeTimer(frequency: usize) void {
    _ = frequency;
}

pub fn initializeConsole() void {}

pub fn setColor(color: arch.TextColor) void {
    _ = color;
}

pub const Writer = std.io.GenericWriter(
    void,
    error{},
    struct {
        fn write(_: void, bytes: []const u8) !usize {
            return bytes.len;
        }
    }.write,
);

pub fn writer() Writer {
    return .{ .context = {} };
}
