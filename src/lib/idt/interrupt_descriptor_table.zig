const std = @import("std");
const kernel_common = @import("../kernel_common.zig");
const port_io = @import("../port-io.zig");

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

pub fn initialize() !void {
    interrupt_descriptor_table_register.limit = @sizeOf(@TypeOf(interrupt_descriptor_table)) - 1;
    interrupt_descriptor_table_register.base = @intFromPtr(&interrupt_descriptor_table);

    for (0..TOTAL_INTERRUPTS) |i| {
        set(@truncate(i), @intFromPtr(&no_interrupt_handler), 0xEE);
    }
    //set(0x00, @intFromPtr(&idt_zero), 0xEE);
    //set(0x01, @intFromPtr(&debug_exception), 0xEE);
    //set(0x06, @intFromPtr(&invalid_opcode), 0xEE);
    //set(0x08, @intFromPtr(&double_fault), 0xEE);
    //set(0x0A, @intFromPtr(&invalid_tss), 0xEE);
    //set(0x0C, @intFromPtr(&stack_segment_fault), 0xEE);
    //set(0x0D, @intFromPtr(&general_protection_fault), 0xEE);
    //set(0x0E, @intFromPtr(&page_fault), 0xEE);
    //set(0x11, @intFromPtr(&alignment_check), 0xEE);
    //set(0x20, @intFromPtr(&timer_interrupt), 0xEE);
    //set(0x21, @intFromPtr(&int21h_handler), 0xEE);

    //for (34..TOTAL_INTERRUPTS) |i| {
    //    set(@truncate(i), @intFromPtr(&non_intel), 0xEE);
    //}

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

fn int21h_handler() void {
    asm volatile (
        \\cli
    );
    kernel_common.printString("Keyboard Pressed!\n");
    acknowledge_interrupt();
}

fn no_interrupt_handler() callconv(.Naked) noreturn {
    //asm volatile (
    //    \\pusha
    //);
    //kernel_common.printString("No Interrupt!\n");
    //port_io.out8(0x20, 0x20);
    asm volatile (
    //    \\popa
        \\iret
    );
    //unreachable;
}

fn idt_load() void {
    asm volatile (
        \\push %ebp
        \\mov %esp, %ebp
        \\lidt (%ebx)
        \\sti
        :
        : [interrupt_descriptor_table_register] "{ebx}" (&interrupt_descriptor_table_register),
        : "ebx", "memory"
    );
}

fn idt_zero() void {
    kernel_common.printString("Divide by zero error.\n");
    asm volatile (
        \\cli
        \\hlt
    );
    acknowledge_interrupt();
}

fn debug_exception() void {
    kernel_common.printString("Debug exception.\n");
    asm volatile (
        \\cli
        \\hlt
    );
    acknowledge_interrupt();
}

fn no_interrupt() void {
    asm volatile (
        \\cli
        \\call no_interrupt_handler
        \\sti
        \\iret
    );
    acknowledge_interrupt();
}

// A very simple handler for a general protection fault.
// In a real kernel, you might log register state or blink LEDs, etc.
fn general_protection_fault() void {
    kernel_common.printString("General protection fault.\n");
    asm volatile (
        \\cli
        \\hlt
    );
    acknowledge_interrupt();
}

// A simple handler for an invalid opcode fault.
fn invalid_opcode() void {
    kernel_common.printString("Invalid opcode.\n");
    asm volatile (
        \\cli
        \\hlt
    );
    acknowledge_interrupt();
}

// A simple handler for an invalid opcode fault.
fn stack_segment_fault() void {
    kernel_common.printString("Stack segment fault.\n");
    asm volatile (
        \\cli
        \\hlt
    );
    acknowledge_interrupt();
}

fn double_fault() void {
    kernel_common.printString("Double fault.\n");
    asm volatile (
        \\cli
        \\hlt
    );
    acknowledge_interrupt();
}

fn invalid_tss() void {
    kernel_common.printString("Invalid TSS.\n");
    asm volatile (
        \\cli
        \\hlt
    );
    acknowledge_interrupt();
}

fn page_fault() void {
    kernel_common.printString("Page fault.\n");
    asm volatile (
        \\cli
        \\hlt
    );
    acknowledge_interrupt();
}

fn alignment_check() void {
    kernel_common.printString("Alignment check.\n");
    asm volatile (
        \\cli
        \\hlt
    );
    acknowledge_interrupt();
}

fn timer_interrupt() void {
    asm volatile (
        \\cli
    );
    kernel_common.printString("Timer interrupt.\n");
    asm volatile (
        \\sti
        \\iret
    );
    acknowledge_interrupt();
}

fn int21h() void {
    asm volatile (
        \\cli
        \\call int21h_handler
        \\sti
        \\iret
    );
    acknowledge_interrupt();
}

fn non_intel() void {
    kernel_common.printString("Non Intel interrupt.\n");
    asm volatile (
        \\cli
        \\hlt
    );
    acknowledge_interrupt();
}

fn acknowledge_interrupt() void {
    asm volatile (
        \\sti
    );
}
