const std = @import("std");
const kernel_common = @import("../kernel_common.zig");
const port_io = @import("../port-io.zig");

const TOTAL_INTERRUPTS: u16 = 256;

const InterruptDescriptorTableStruct = packed struct {
    offset_low: u16 = 0, // Offset bits 0-15
    selector: u16 = 0, // Selector from GDT
    unused_byte: u8 = 0, // Reserved
    type_attribute: u8 = 0, // Descriptor type and attributes
    offset_high: u16 = 0, // Offset bits 16-31
};

const InterruptDescriptorTableRegisterStruct = packed struct {
    limit: u16 = 0, // Size of descriptor table minus 1
    base: u32 = 0, // Base address of the start of the interrupt descriptor table
};

var interrupt_descriptor_table: [TOTAL_INTERRUPTS]InterruptDescriptorTableStruct =
    [_]InterruptDescriptorTableStruct{.{}} ** TOTAL_INTERRUPTS;

var interrupt_descriptor_table_register: InterruptDescriptorTableRegisterStruct =
    InterruptDescriptorTableRegisterStruct{ .base = undefined };

const Trampoline = *const fn () callconv(.Naked) void;

// Generate a trampoline that pushes its index and calls `target`
fn makeTrampoline(comptime index: u32) Trampoline {
    return struct {
        fn trampoline() callconv(.Naked) void {
            asm volatile (
                \\ push %esp
                \\ push %[index]
                \\ call interrupt_handler
                \\ add $8, %esp
                \\ iret
                :
                : [index] "i" (index),
            );
        }
    }.trampoline;
}

var trampolines: [TOTAL_INTERRUPTS]Trampoline = undefined;

pub fn initialize() !void {
    inline for (0..TOTAL_INTERRUPTS) |vec| {
        trampolines[vec] = makeTrampoline(vec);
        set(@truncate(vec), @intFromPtr(trampolines[vec]), 0x8E);
    }

    interrupt_descriptor_table_register.limit = @sizeOf(@TypeOf(interrupt_descriptor_table)) - 1;
    interrupt_descriptor_table_register.base = @intFromPtr(&interrupt_descriptor_table);

    idt_load();
}

pub fn set(interrupt_number: u16, address: u32, type_attribute: u8) void {
    var interrupt_descriptor: *InterruptDescriptorTableStruct = &interrupt_descriptor_table[interrupt_number];
    interrupt_descriptor.offset_low = @truncate(address & 0xffff);
    interrupt_descriptor.selector = kernel_common.KERNEL_CODE_SELECTOR;
    interrupt_descriptor.unused_byte = 0x00;
    interrupt_descriptor.type_attribute = type_attribute;
    interrupt_descriptor.offset_high = @truncate((address >> 16) & 0xffff);
    return;
}

fn idt_load() void {
    asm volatile (
        \\cli
        \\lidt (%ebx)
        \\sti
        :
        : [interrupt_descriptor_table_register] "{ebx}" (&interrupt_descriptor_table_register),
        : "ebx", "memory"
    );
}

export fn interrupt_handler(index: u32, stack_pointer: u32) callconv(.C) void {
    kernel_common.printString("Interrupt: ");
    switch (index) {
        0x00 => {
            kernel_common.printString("Divide by zero.");
        },
        0x01 => {
            kernel_common.printString("Debug exception.");
        },
        0x02...0x05 => {},
        0x06 => {
            kernel_common.printString("Invalid opcode.");
        },
        0x07 => {},
        0x08 => {
            kernel_common.printString("Double fault.");
        },
        0x09 => {},
        0x0A => {
            kernel_common.printString("Invalid TSS.");
        },
        0x0B => {},
        0x0C => {
            kernel_common.printString("Stack segment fault.");
        },
        0x0D => {
            kernel_common.printString("General protection fault.");
            kernel_common.printFormat(" Stack Index: {x}\n", .{stack_pointer});
            asm volatile (
                \\cli
                \\hlt
            );
        },
        0x0E => {
            kernel_common.printString("Page fault.");
        },
        0x0F => {},
        0x10 => {},
        0x11 => {
            kernel_common.printString("Alignment check.");
        },
        0x12...0x1F => {},
        0x20 => {
            kernel_common.printString("Timer.");
        },
        0x21 => {
            kernel_common.printString("Keyboard pressed.");
            _ = port_io.in8(0x60);
        },
        0x22...0xFFFFFFFF => {},
    }

    kernel_common.printFormat(" --- Stack Index: {x}\n", .{stack_pointer});
    //var i: usize = 0;
    //while (i < 1000000000) : (i += 1) {
    //    asm volatile ("" ::: "memory"); // prevent loop being optimized away
    //}
    port_io.out8(0x20, 0x20);
    port_io.out8(0xA0, 0x20);
}
