const builtin = @import("builtin");

const Arch = @import("architecture/architecture.zig");
pub const arch = Arch.getArch();
pub const pmm = @import("common/memory_management/pmm.zig");
const std = @import("std");

pub export fn kernelMain() void {
    arch.startup.finishStartup();
    arch.console.initialize();
    arch.console.printLog("Initializing interrupts...", Arch.Arch.Console.LogLevel.infoText);

    arch.interrupts.initialize();
    arch.interrupts.enableInterrupts();
    arch.console.printLog("done!\n", Arch.Arch.Console.LogLevel.noticeText);

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
    _ = message;
    // arch.console.print("\n!KERNEL PANIC!\n");
    // arch.console.print(message);
    // arch.console.print("\n");
    _ = stack_trace;
    _ = number;
    while (true) {}
}
