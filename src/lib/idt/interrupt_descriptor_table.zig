const std = @import("std");
const kernel_common = @import("../kernel_common.zig");

const TOTAL_INTERRUPTS: u16 = 512;

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

pub fn initialize() void {
    interrupt_descriptor_table_register.limit = @sizeOf(@TypeOf(interrupt_descriptor_table)) - 1;
    interrupt_descriptor_table_register.base = @intFromPtr(&interrupt_descriptor_table);

    set(0, @intFromPtr(&idt_zero), 0xEE);

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
        \\lidt (%ebx)
        :
        : [interrupt_descriptor_table_register] "{ebx}" (&interrupt_descriptor_table_register),
        : "ebx", "memory"
    );
}

fn idt_zero() void {
    kernel_common.printError("Divide by zero error.\n");

    asm volatile (
        \\hlt
    );
}
