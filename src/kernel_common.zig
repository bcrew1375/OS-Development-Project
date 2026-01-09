const std = @import("std");

const terminal = @import("terminal.zig");
const gdt = @import("gdt.zig");
const idt = @import("idt/interrupt_descriptor_table.zig");
const pmm = @import("memory/pmm/pmm.zig");
const kernel_heap = @import("../lib/memory/kernel_heap.zig");
const paging = @import("../lib/memory/paging.zig");
const port_io = @import("../lib/port-io.zig");

pub const KERNEL_CODE_SELECTOR: u8 = 0x08;
pub const KERNEL_DATA_SELECTOR: u8 = 0x10;

pub export fn kernelMain() void {
    //Set 100 Hz PIT divisor. 1193182 / 100 = ~100 Hz
    const PIT_DIVISOR: u16 = 65535;
    port_io.out8(0x43, 0b00110100);
    port_io.out8(0x40, @truncate(PIT_DIVISOR & 0xFF));
    port_io.out8(0x40, @truncate(PIT_DIVISOR >> 8));

    terminal.initialize();
    pmm.initialize();

    // Test PMM function integrity.
    {
        var err = pmm.PmmError.InvalidSize;
        if (pmm.allocate(0) != err) {
            printFormat("PMM {s} testing failed!", .{@errorName(err)});
            unrecoverableHalt();
        }
        if (pmm.allocate(pmm.TOTAL_NUMBER_OF_FRAMES - pmm.KERNEL_BASE_FRAMES_COUNT + 1) != err) {
            printFormat("PMM {s} testing failed!", .{@errorName(err)});
            unrecoverableHalt();
        }

        err = pmm.PmmError.OutOfMemory;
        if (pmm.allocate(pmm.TOTAL_NUMBER_OF_FRAMES - pmm.KERNEL_BASE_FRAMES_COUNT) == err) {
            printFormat("PMM {s} testing failed!", .{@errorName(err)});
            unrecoverableHalt();
        }
        if (pmm.allocate(1) != err) {
            printFormat("PMM {s} testing failed!", .{@errorName(err)});
            unrecoverableHalt();
        }

        err = pmm.PmmError.InvalidIndex;
        // Free RAM from OutOfMemory test.
        if (pmm.free(pmm.KERNEL_BASE_FRAMES_COUNT, pmm.TOTAL_NUMBER_OF_FRAMES - pmm.KERNEL_BASE_FRAMES_COUNT) == err) {
            printFormat("PMM {s} testing failed!", .{@errorName(err)});
            unrecoverableHalt();
        }

        if (pmm.free(0, pmm.KERNEL_BASE_FRAMES_COUNT) != err) {
            printFormat("PMM {s} testing failed!", .{@errorName(err)});
            unrecoverableHalt();
        }
        if (pmm.free(pmm.TOTAL_NUMBER_OF_FRAMES, 1) != err) {
            printFormat("PMM {s} testing failed!", .{@errorName(err)});
            unrecoverableHalt();
        }
    }

    gdt.initialize();
    paging.removeIdentityMapping();

    idt.initialize() catch |err| {
        printString(@errorName(err));
        unrecoverableHalt();
    };

    // kernel_heap.initialize() catch |err| {
    //     printString(@errorName(err));
    //     unrecoverableHalt();
    // };
    // disableInterrupts();
    // paging.makePageDirectory(0x03) catch |err| {
    //     printString(@errorName(err));
    //     unrecoverableHalt();
    // };
    enableInterrupts();
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

pub fn enableInterrupts() void {
    asm volatile (
        \\sti
    );
}

pub fn disableInterrupts() void {
    asm volatile (
        \\cli
    );
}
