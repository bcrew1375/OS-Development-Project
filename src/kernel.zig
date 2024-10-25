const kernel_common = @import("lib/kernel_common.zig");
const terminal = @import("lib/terminal.zig");
const portio = @import("lib/port-io.zig");
const heap = @import("lib/memory/heap.zig");
const math = @import("std").math;

pub const MESSAGE = "Aello,World!\n";

pub export fn kernelMain() void {
    kernel_common.kernelInitialize();
    terminal.initialize();
    terminal.print(MESSAGE);

    heap.initialize(0x300000, 0x4000000);
    const memory_block: []i8 = @as([*]i8, @ptrCast(heap.malloc(20)))[0..20];

    for (0..20) |i| {
        memory_block[i] = @as(i8, @intCast(i - 10));
        terminal.print(kernel_common.numberToString(@intCast(memory_block[i])));
        terminal.print("\n");
    }
}
