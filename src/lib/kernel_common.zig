const std = @import("std");

const idt = @import("idt/interrupt_descriptor_table.zig");
const terminal = @import("terminal.zig");
const heap = @import("../lib/memory/heap.zig");

pub const KERNEL_CODE_SELECTOR: u8 = 0x08;
pub const KERNEL_DATA_SELECTOR: u8 = 0x10;

pub fn kernelInitialize() void {
    idt.initialize();
}

pub fn printError(string: []const u8) void {
    terminal.print(string);
}

pub fn numberToString(number: i32) []u8 {
    const is_negative: bool = (number < 0);

    var buffer_position: u8 = 20;
    var absolute_number: u32 = @abs(number);

    const digits_buffer: []u8 = @as([*]u8, @ptrCast(heap.malloc(20 - buffer_position)))[buffer_position..20];

    if (absolute_number == 0) {
        buffer_position -= 1;
        digits_buffer[buffer_position] = '0';
    } else {
        while (absolute_number > 0) {
            buffer_position -= 1;
            digits_buffer[buffer_position] = ('0' + @as(u8, @truncate(absolute_number % 10)));
            absolute_number /= 10;
        }
    }

    if (is_negative == true) {
        buffer_position -= 1;
        digits_buffer[buffer_position] = '-';
    }

    return digits_buffer[buffer_position..20];
}
