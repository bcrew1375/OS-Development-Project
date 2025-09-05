const std = @import("std");

const idt = @import("idt/interrupt_descriptor_table.zig");
const terminal = @import("terminal.zig");
const kernel_heap = @import("../lib/memory/kernel_heap.zig");
const paging = @import("../lib/memory/paging.zig");

pub const KERNEL_CODE_SELECTOR: u8 = 0x08;
pub const KERNEL_DATA_SELECTOR: u8 = 0x10;

pub const COLOR = enum(u8) {
    BLACK = 0,
    BLUE = 1,
    GREEN = 2,
    CYAN = 3,
    RED = 4,
    MAGENTA = 5,
    BROWN = 6,
    LIGHT_GRAY = 7,
    DARK_GRAY = 8,
    LIGHT_BLUE = 9,
    LIGHT_GREEN = 10,
    LIGHT_CYAN = 11,
    LIGHT_RED = 12,
    LIGHT_MAGENTA = 13,
    YELLOW = 14,
    WHITE = 15,
};

pub fn kernelInitialize() !void {
    terminal.initialize();
    kernel_heap.initialize() catch |err| {
        printString(@errorName(err));
        unrecoverableHalt();
    };
    idt.initialize() catch |err| {
        printString(@errorName(err));
        unrecoverableHalt();
    };
    _ = paging.makePageDirectoryEntry(0) catch |err| {
        printString(@errorName(err));
        unrecoverableHalt();
    };
}

pub fn printString(string: []const u8) void {
    terminal.print(string);
}

pub fn printStringColor(string: []const u8, color: COLOR) void {
    terminal.printColor(string, color);
}

pub fn printFormat(comptime string_fmt: []const u8, args: anytype) void {
    var string_buffer: [256]u8 = undefined;

    const string_slice = std.fmt.bufPrint(&string_buffer, string_fmt, args) catch |format_err| {
        printString(@errorName(format_err));
        return;
    };

    printString(string_slice);
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

pub fn unrecoverableHalt() noreturn {
    asm volatile (
        \\cli
        \\hlt
    );
    unreachable;
}
