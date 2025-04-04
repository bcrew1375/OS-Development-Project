const std = @import("std");

const idt = @import("idt/interrupt_descriptor_table.zig");
const terminal = @import("terminal.zig");
const kernel_heap = @import("../lib/memory/kernel_heap.zig");

pub const KERNEL_CODE_SELECTOR: u8 = 0x08;
pub const KERNEL_DATA_SELECTOR: u8 = 0x10;

pub fn kernelInitialize() !void {
    terminal.initialize();

    printString("Initializing Interrupt Descriptor Table...");
    try idt.initialize();
    printString("done\n");

    printString("Initializing Kernel Heap...");
    try kernel_heap.initialize();
    printString("done\n");

    printFormat("Number Test {d} {d}\n", .{ 0, 1 });
}

pub fn printString(string: []const u8) void {
    terminal.print(string);
}

pub fn printFormat(comptime string: []const u8, args: anytype) void {
    var string_buffer: [256]u8 = undefined;

    const string_slice = std.fmt.bufPrint(&string_buffer, string, args) catch |format_err| {
        printString(@errorName(format_err));
        return;
    };

    terminal.print(string_slice);
}

pub fn printNumber(number: i32) void {
    var digits_buffer: [20]u8 = undefined;
    const length = numberToString(number, digits_buffer[0..]);

    terminal.print(digits_buffer[0..length]);
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
