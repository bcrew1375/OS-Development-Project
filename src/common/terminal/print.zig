//! Simple terminal printing helpers.

const arch = @import("arch");

const std = @import("std");

const DEFAULT_COLOR = arch.TextColor.WHITE;

/// Writes a string using the default terminal color.
pub fn printString(string: []const u8) void {
    arch.platform.setColor(DEFAULT_COLOR);
    arch.platform.writer().writeAll(string) catch {};
}

/// Writes a string in `color`, then restores the default terminal color.
pub fn printStringColor(string: []const u8, color: arch.TextColor) void {
    arch.platform.setColor(color);
    arch.platform.writer().writeAll(string) catch {};
    arch.platform.setColor(DEFAULT_COLOR);
}
