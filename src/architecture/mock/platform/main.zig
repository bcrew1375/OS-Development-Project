const std = @import("std");

pub fn initializeConsole() void {}
pub fn initializeTimer() void {}
pub fn print(string: []const u8) void {
    std.debug.print("{s}", .{string});
}
pub fn printLog(string: []const u8) void {
    std.debug.print("{s}", .{string});
}
