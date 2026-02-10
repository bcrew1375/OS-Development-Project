const arch = @import("../../kernel.zig").arch;

const std = @import("std");

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
