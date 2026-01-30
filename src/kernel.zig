const builtin = @import("builtin");

const Arch = @import("architecture/architecture.zig");
//pub const pmm = @import("memory_management/pmm.zig");
const arch = Arch.getArch();
const std = @import("std");

pub export fn kernelMain() void {
    arch.startup.finishStartup();
    arch.console.initialize();
    arch.console.printLog("Hello, World!", Arch.Arch.Console.LogLevel.noticeText);
    //pmm.initialize();

    // kernel_heap.initialize() catch |err| {
    //     printString(@errorName(err));
    //     unrecoverableHalt();
    // };
    // disableInterrupts();
    // paging.makePageDirectory(0x03) catch |err| {
    //     printString(@errorName(err));
    //     unrecoverableHalt();
    // };
    //arch.interrupts.enableInterrupts();
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

export fn interrupt_handler(index: usize, stack_pointer: usize) callconv(.c) void {
    // Not ready to handle nested interrupts. Don't risk stack overflow.
    //arch.interrupts.disableInterrupts();
    printString("Interrupt: ");
    switch (index) {
        0x00 => {
            printString("Divide by zero.\n");
        },
        0x01 => {
            printString("Debug exception.\n");
        },
        0x02...0x05 => {},
        0x06 => {
            printString("Invalid opcode.\n");
        },
        0x07 => {},
        0x08 => {
            printString("Double fault.\n");
        },
        0x09 => {},
        0x0A => {
            printString("Invalid TSS.\n");
        },
        0x0B => {},
        0x0C => {
            printString("Stack segment fault.\n");
        },
        0x0D => {
            printString("General protection fault.\n");
            printFormat(" Stack Index: {x}\n", .{stack_pointer});
            //arch.cpu.unrecoverableHalt();
        },
        0x0E => {
            const stack_array: *[4]usize = @ptrFromInt(stack_pointer);
            const error_code: usize = stack_array[0];
            const virtual_address: usize = stack_array[1];
            printString("Page fault.\n");
            printFormat("Error code: 0x{x}\n", .{error_code});
            printFormat("Virtual address: 0x{x}\n", .{virtual_address});
            //printFormat("Physical address: 0x{x}\n", .{arch.paging.getPhysicalAddress(virtual_address)});
        },
        0x0F => {},
        0x10 => {},
        0x11 => {
            printString("Alignment check.\n");
        },
        0x12...0x1F => {},
        0x20 => {
            printString("Timer.\n");
        },
        0x21 => {
            printString("Keyboard pressed.\n");
            //arch.keyboard.clearKeyboard();
        },
        0x22...0xFFFFFFFF => {},
    }

    printFormat(" --- Stack Index: {x}\n", .{stack_pointer});

    //arch.interrupts.acknowledgeInterrupt();
    //arch.interrupts.enableInterrupts();
}
