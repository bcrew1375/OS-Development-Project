const LogLevels = @import("arch").LogLevels;

const std = @import("std");

pub fn initializeConsole() void {}
pub fn initializeTimer(frequency: usize) void {
    _ = frequency;
}
pub fn print(string: []const u8) void {
    std.debug.print("{s}", .{string});
}
pub fn printLog(string: []const u8, logLevel: LogLevels) void {
    _ = logLevel;
    std.debug.print("{s}", .{string});
}
