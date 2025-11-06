const std = @import("std");
const kernel_common = @import("../kernel_common.zig");
const port_io = @import("../port-io.zig");
const paging = @import("../memory/paging.zig");

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

const Trampoline = *const fn () callconv(.naked) noreturn;

// Generate a trampoline that pushes its index and calls `target`
fn makeTrampoline(comptime index: u32) Trampoline {
    return struct {
        fn trampoline() align(16) callconv(.naked) noreturn {
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
    kernel_common.printString("Initializing Interrupt Descriptor Table...");
    inline for (0..TOTAL_INTERRUPTS) |vec| {
        trampolines[vec] = makeTrampoline(vec);
        set(@truncate(vec), @intFromPtr(trampolines[vec]), 0x8E);
    }

    interrupt_descriptor_table_register.limit = @sizeOf(@TypeOf(interrupt_descriptor_table)) - 1;
    interrupt_descriptor_table_register.base = @intFromPtr(&interrupt_descriptor_table);

    idt_load();
    kernel_common.printStringColor("done\n", kernel_common.COLOR.GREEN);
}

pub fn set(interrupt_number: u16, address: usize, type_attribute: u8) void {
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
        :
        : [interrupt_descriptor_table_register] "{ebx}" (&interrupt_descriptor_table_register),
        : .{ .ebx = true, .memory = true });
}

export fn interrupt_handler(index: usize, stack_pointer: usize) callconv(.c) void {
    // Not ready to handle nested interrupts. Don't risk stack overflow.
    kernel_common.disableInterrupts();
    kernel_common.printString("\nInterrupt: ");
    switch (index) {
        0x00 => {
            kernel_common.printString("Divide by zero.\n");
        },
        0x01 => {
            kernel_common.printString("Debug exception.\n");
        },
        0x02...0x05 => {},
        0x06 => {
            kernel_common.printString("Invalid opcode.\n");
        },
        0x07 => {},
        0x08 => {
            kernel_common.printString("Double fault.\n");
        },
        0x09 => {},
        0x0A => {
            kernel_common.printString("Invalid TSS.\n");
        },
        0x0B => {},
        0x0C => {
            kernel_common.printString("Stack segment fault.\n");
        },
        0x0D => {
            kernel_common.printString("General protection fault.\n");
            kernel_common.printFormat(" Stack Index: {x}\n", .{stack_pointer});
            kernel_common.unrecoverableHalt();
        },
        0x0E => {
            const stack_array: *[4]usize = @ptrFromInt(stack_pointer);
            const error_code: usize = stack_array[0];
            const virtual_address: usize = stack_array[1];
            kernel_common.printString("Page fault.\n");
            kernel_common.printFormat("Error code: 0x{x}\n", .{error_code});
            kernel_common.printFormat("Virtual address: 0x{x}\n", .{virtual_address});
            kernel_common.printFormat("Physical address: 0x{x}\n", .{paging.getPhysicalAddress(virtual_address)});
        },
        0x0F => {},
        0x10 => {},
        0x11 => {
            kernel_common.printString("Alignment check.\n");
        },
        0x12...0x1F => {},
        0x20 => {
            kernel_common.printString("Timer.\n");
        },
        0x21 => {
            kernel_common.printString("Keyboard pressed.\n");
            _ = port_io.in8(0x60);
        },
        0x22...0xFFFFFFFF => {},
    }

    kernel_common.printFormat(" --- Stack Index: {x}\n", .{stack_pointer});

    // Waste some time to slow down printing.
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        asm volatile ("" ::: .{ .memory = true }); // prevent loop being optimized away
    }

    acknowledgeInterrupt();
    kernel_common.enableInterrupts();
}

pub fn acknowledgeInterrupt() void {
    port_io.out8(0x20, 0x20);
    port_io.out8(0xA0, 0x20);
}
