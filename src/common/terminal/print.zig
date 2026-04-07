const arch = @import("arch");

const std = @import("std");

pub fn printString(string: []const u8) void {
    arch.platform.print(string);
}

pub fn printStringColor(string: []const u8, logLevel: arch.LogLevels) void {
    arch.platform.printLog(string, logLevel);
}
