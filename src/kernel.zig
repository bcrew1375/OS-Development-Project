const builtin = @import("builtin");

const arch = @import("arch").impl;
const pmm = @import("kernel_common").pmm;
const terminal = @import("kernel_common").terminal;
const LogLevels = @import("arch").LogLevels;

const std = @import("std");

pub export fn kernelMain() void {
    arch.boot.finishBoot();
    pmm.initialize();

    terminal.initialize();
    terminal.print.printStringColor("Initializing interrupts...", LogLevels.infoText);
    arch.interrupts.initialize();
    arch.interrupts.enableInterrupts();
    terminal.print.printStringColor("done!\n", LogLevels.infoText);

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
    arch.platform.print("\n!KERNEL PANIC!\n");
    arch.platform.print(message);
    arch.platform.print("\n");
    _ = stack_trace;
    _ = number;
    while (true) {}
}
