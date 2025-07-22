var allocator = @import("std").heap.GeneralPurposeAllocator(.{}){};

const kernel_common = @import("lib/kernel_common.zig");
const terminal = @import("lib/terminal.zig");
const std = @import("std");

pub const MESSAGE = "Aello,World!\n";

pub export fn kernelMain() void {
    kernel_common.kernelInitialize() catch |err| {
        kernel_common.printString(@errorName(err));
    };
}

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, number: ?usize) noreturn {
    terminal.print("\n!KERNEL PANIC!\n");
    terminal.print(message);
    terminal.print("\n");
    _ = stack_trace;
    _ = number;
    while (true) {}
}
