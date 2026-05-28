const arch = @import("../../architecture.zig");
const std = @import("std");

pub fn initializeTimer(frequency: usize) void {
    _ = frequency;
}

pub fn initializeConsole() void {}

pub fn setColor(color: arch.TextColor) void {
    _ = color;
}

/// Provides a no-op writer that satisfies the Zig Allocator/Logger requirements.
pub const writer = std.io.GenericWriter(
    void,
    error{},
    struct {
        fn write(context: void, bytes: []const u8) !usize {
            _ = context;
            return bytes.len;
        }
    }.write,
){ .context = {} };
