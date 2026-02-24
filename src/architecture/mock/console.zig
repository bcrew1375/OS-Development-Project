const console = @import("../architecture.zig").Arch.Console;

const std = @import("std");

pub fn Console() console {
    return console{
        .initialize = struct {
            fn initialize() void {}
        }.initialize,

        .print = struct {
            fn print(string: []const u8) void {
                std.debug.print("{s}", .{string});
            }
        }.print,

        .printLog = struct {
            fn printLog(string: []const u8, logLevel: console.LogLevel) void {
                std.debug.print("{s}", .{string});
                _ = logLevel;
            }
        }.printLog,
    };
}
