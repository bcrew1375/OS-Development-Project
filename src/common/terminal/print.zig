const arch = @import("arch");

const std = @import("std");

const DEFAULT_COLOR = arch.TextColor.WHITE;

pub fn printString(string: []const u8) void {
    arch.platform.setColor(DEFAULT_COLOR);
    arch.platform.writer().writeAll(string) catch {};
}

pub fn printStringColor(string: []const u8, color: arch.TextColor) void {
    arch.platform.setColor(color);
    arch.platform.writer().writeAll(string) catch {};
    arch.platform.setColor(DEFAULT_COLOR);
}
