var allocator = @import("std").heap.GeneralPurposeAllocator(.{}){};

const kernel_common = @import("lib/kernel_common.zig");
const terminal = @import("lib/terminal.zig");
const portio = @import("lib/port-io.zig");
const heap = @import("lib/memory/heap.zig");
const math = @import("std").math;
//const print = @import("std").debug.print;

pub const MESSAGE = "Aello,World!\n";

pub export fn kernelMain() void {
    kernel_common.kernelInitialize();
    terminal.initialize();

    kernel_common.printString(MESSAGE);
    kernel_common.printNumber(-4096);
}
