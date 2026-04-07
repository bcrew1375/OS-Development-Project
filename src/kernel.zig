const builtin = @import("builtin");

const arch = @import("arch").impl;
const pmm = @import("kernel_common").pmm;
const terminal = @import("kernel_common").terminal;
const TextColor = @import("arch").TextColor;

const std = @import("std");

pub export fn kernelMain() void {
    arch.boot.finishBoot();
    pmm.initialize();
    terminal.initialize();
    terminal.print.printStringColor("Initializing interrupts...", TextColor.WHITE);
    arch.interrupts.initialize();
    arch.interrupts.enableInterrupts();
    terminal.print.printStringColor("done!\n", TextColor.GREEN);

    pmm.initialize();

    // kernel_heap.initialize() catch |err| {
    //     printString(@errorName(err));
    //     unrecoverableHalt();
    // };
    // disableInterrupts();
    // paging.makePageDirectory(0x03) catch |err| {
    //     printString(@errorName(err));
    //     unrecoverableHalt();
    // };
}

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, number: ?usize) noreturn {
    arch.interrupts.disableInterrupts();
    arch.platform.setColor(TextColor.RED);
    arch.platform.writer.writeAll("\n!KERNEL PANIC!\n") catch {};
    arch.platform.writer.writeAll(message) catch {};
    arch.platform.writer.writeAll("\n") catch {};
    _ = stack_trace;
    _ = number;
    while (true) {}
}
