const gdt = @import("global_descriptor_table.zig");
const interruptHandler = @import("main.zig").interruptHandler;
const port_io = @import("../platform/io/port_io.zig");

const std = @import("std");

const TOTAL_INTERRUPTS: usize = 256;

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

comptime {
    std.debug.assert(@sizeOf(InterruptDescriptorTableStruct) == 8);
    std.debug.assert(@bitSizeOf(InterruptDescriptorTableRegisterStruct) == 48);
}

const Trampoline = *const fn () callconv(.naked) noreturn;

var interrupt_descriptor_table: [TOTAL_INTERRUPTS]InterruptDescriptorTableStruct align(16) =
    [_]InterruptDescriptorTableStruct{.{}} ** TOTAL_INTERRUPTS;

var interrupt_descriptor_table_register: InterruptDescriptorTableRegisterStruct align(16) =
    InterruptDescriptorTableRegisterStruct{ .base = undefined };

var trampolines: [TOTAL_INTERRUPTS]Trampoline = undefined;

pub fn initialize() void {
    inline for (0..TOTAL_INTERRUPTS) |vector| {
        trampolines[vector] = makeTrampoline(vector);
        set(@truncate(vector), @intFromPtr(trampolines[vector]), 0x8E);
    }

    interrupt_descriptor_table_register.limit = @sizeOf(@TypeOf(interrupt_descriptor_table)) - 1;
    interrupt_descriptor_table_register.base = @intFromPtr(&interrupt_descriptor_table);

    idtLoad();

    port_io.out8(0x20, 0x11); // ICW1: start init, edge triggered, ICW4 needed
    port_io.out8(0x21, 0x20); // ICW2: IRQ0 → INT 0x20
    port_io.out8(0x21, 0x04); // ICW3: slave on IRQ2
    port_io.out8(0x21, 0x01); // ICW4: 8086 mode

    // Disable timer for now.
    port_io.out8(0x21, 0x01); // ICW4: 8086 mode
}

pub fn set(interruptVector: usize, address: usize, typeAttribute: usize) void {
    var interrupt_descriptor: *InterruptDescriptorTableStruct = &interrupt_descriptor_table[interruptVector];
    interrupt_descriptor.offset_low = @truncate(address & 0xffff);
    interrupt_descriptor.selector = gdt.CODE_SELECTOR;
    interrupt_descriptor.unused_byte = 0x00;
    interrupt_descriptor.type_attribute = @truncate(typeAttribute);
    interrupt_descriptor.offset_high = @truncate(address >> 16);
    return;
}

// Generate a trampoline that calls the interrupt handler with the interrupt number.
fn makeTrampoline(comptime vector: u32) Trampoline {
    return struct {
        fn trampoline() align(16) callconv(.naked) noreturn {
            asm volatile (
                \\push %esp
                \\push %[vector]
                \\call interruptHandler
                \\add $8, %esp
                \\iret
                :
                : [vector] "i" (vector),
                  [interruptHandler] "i" (&interruptHandler),
            );
        }
    }.trampoline;
}

fn idtLoad() void {
    asm volatile (
        \\cli
        \\lidt (%[interrupt_descriptor_table_register])
        :
        : [interrupt_descriptor_table_register] "{ecx}" (&interrupt_descriptor_table_register),
        : .{ .ecx = true, .memory = true });
}
