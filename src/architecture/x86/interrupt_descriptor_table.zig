const interrupts = @import("../architecture.zig").Arch.Interrupts;
const std = @import("std");
const gdt = @import("global_descriptor_table.zig");
const port_io = @import("port_io.zig");

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

const Trampoline = *const fn () callconv(.naked) noreturn;

var interrupt_descriptor_table: [TOTAL_INTERRUPTS]InterruptDescriptorTableStruct align(16) =
    [_]InterruptDescriptorTableStruct{.{}} ** TOTAL_INTERRUPTS;

var interrupt_descriptor_table_register: InterruptDescriptorTableRegisterStruct align(16) =
    InterruptDescriptorTableRegisterStruct{ .base = undefined };

var trampolines: [TOTAL_INTERRUPTS]Trampoline = undefined;

pub fn Interrupts() interrupts {
    return interrupts{
        .initialize = struct {
            fn initialize() void {
                inline for (0..TOTAL_INTERRUPTS) |vec| {
                    trampolines[vec] = makeTrampoline(vec);
                    interrupts.set(@truncate(vec), @intFromPtr(trampolines[vec]), 0x8E);
                }

                interrupt_descriptor_table_register.limit = @sizeOf(@TypeOf(interrupt_descriptor_table)) - 1;
                interrupt_descriptor_table_register.base = @intFromPtr(&interrupt_descriptor_table);

                idtLoad();
            }
        }.initialize,

        .set = struct {
            fn set(interrupt_number: u16, address: usize, type_attribute: u8) void {
                var interrupt_descriptor: *InterruptDescriptorTableStruct = &interrupt_descriptor_table[interrupt_number];
                interrupt_descriptor.offset_low = @truncate(address & 0xffff);
                interrupt_descriptor.selector = gdt.CODE_SELECTOR;
                interrupt_descriptor.unused_byte = 0x00;
                interrupt_descriptor.type_attribute = type_attribute;
                interrupt_descriptor.offset_high = @truncate(address >> 16);
                return;
            }
        }.set,

        .acknowledgeInterrupt = struct {
            fn acknowledgeInterrupt() void {
                port_io.out8(0x20, 0x20);
                port_io.out8(0xA0, 0x20);
            }
        }.acknowledgeInterrupt,
    };
}

// Generate a trampoline that calls the interrupt handler with the interrupt number.
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

fn idtLoad() void {
    asm volatile (
        \\cli
        \\lidt (%ecx)
        :
        : [interrupt_descriptor_table_register] "{ecx}" (&interrupt_descriptor_table_register),
        : .{ .ecx = true, .memory = true });
}
