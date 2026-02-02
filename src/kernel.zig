const builtin = @import("builtin");

const Arch = @import("architecture/architecture.zig");
//pub const pmm = @import("memory_management/pmm.zig");
pub const arch = Arch.getArch();
const std = @import("std");

pub export fn kernelMain() void {
    arch.startup.finishStartup();
    arch.console.initialize();
    arch.console.printLog("Initializing interrupts...", Arch.Arch.Console.LogLevel.infoText);
    arch.interrupts.initialize();
    arch.interrupts.enableInterrupts();
    arch.console.printLog("done!\n", Arch.Arch.Console.LogLevel.noticeText);

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

pub fn printString(string: []const u8) void {
    arch.console.print(string);
}

pub fn printStringColor(string: []const u8, color: arch.terminal.COLOR) void {
    arch.console.printLog(string, color);
}

pub fn printFormat(comptime string_fmt: []const u8, args: anytype) void {
    var string_buffer: [256]u8 = undefined;

    const string_slice = std.fmt.bufPrint(&string_buffer, string_fmt, args) catch |format_err| {
        printString(@errorName(format_err));
        return;
    };

    printString(string_slice);
}

// Accepts a buffer to return the number as a string
// digits_buffer must always be a []u8 of size 20.
pub fn numberToString(number: i32, digits_buffer: *[20]u8) u8 {
    const is_negative: bool = (number < 0);

    var result: [20]u8 = undefined;
    var buffer_position: u8 = 20;
    var absolute_number: u32 = @abs(number);

    if (absolute_number == 0) {
        buffer_position -= 1;
        result[buffer_position] = '0';
    } else {
        while (absolute_number > 0) {
            buffer_position -= 1;
            result[buffer_position] = ('0' + @as(u8, @truncate(absolute_number % 10)));
            absolute_number /= 10;
        }
    }

    if (is_negative == true) {
        buffer_position -= 1;
        result[buffer_position] = '-';
    }

    std.mem.copyForwards(u8, digits_buffer[0..(20 - buffer_position)], result[buffer_position..20]);

    //Length
    return 20 - buffer_position;
}

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, number: ?usize) noreturn {
    arch.console.print("\n!KERNEL PANIC!\n");
    arch.console.print(message);
    arch.console.print("\n");
    _ = stack_trace;
    _ = number;
    while (true) {}
}
