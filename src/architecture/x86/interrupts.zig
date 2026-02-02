const interrupts = @import("../architecture.zig").Arch.Interrupts;
const idt = @import("interrupt_descriptor_table.zig");
const port_io = @import("port_io.zig");
const keyboard = @import("keyboard.zig");

const arch = @import("../../kernel.zig").arch;
const printString = @import("../../kernel.zig").printString;
const printFormat = @import("../../kernel.zig").printFormat;

pub fn Interrupts() interrupts {
    return interrupts{
        .initialize = idt.initialize,

        .set = idt.set,

        .enableInterrupts = struct {
            fn enableInterrupts() void {
                asm volatile (
                    \\sti
                );
            }
        }.enableInterrupts,

        .disableInterrupts = struct {
            fn disableInterrupts() void {
                asm volatile (
                    \\cli
                );
            }
        }.disableInterrupts,

        .acknowledgeInterrupt = struct {
            fn acknowledgeInterrupt() void {
                port_io.out8(0x20, 0x20);
                port_io.out8(0xA0, 0x20);
            }
        }.acknowledgeInterrupt,
    };
}

export fn interrupt_handler(index: usize, stack_pointer: usize) callconv(.c) void {
    // Not ready to handle nested interrupts. Don't risk stack overflow.
    //arch.interrupts.disableInterrupts();
    printString("Interrupt: ");
    switch (index) {
        0x00 => {
            printString("Divide by zero.\n");
        },
        0x01 => {
            printString("Debug exception.\n");
        },
        0x02...0x05 => {},
        0x06 => {
            printString("Invalid opcode.\n");
        },
        0x07 => {},
        0x08 => {
            printString("Double fault.\n");
        },
        0x09 => {},
        0x0A => {
            printString("Invalid TSS.\n");
        },
        0x0B => {},
        0x0C => {
            printString("Stack segment fault.\n");
        },
        0x0D => {
            printString("General protection fault.\n");
            printFormat(" Stack Index: {x}\n", .{stack_pointer});
            //arch.cpu.unrecoverableHalt();
        },
        0x0E => {
            const stack_array: *[4]usize = @ptrFromInt(stack_pointer);
            const error_code: usize = stack_array[0];
            const virtual_address: usize = stack_array[1];
            printString("Page fault.\n");
            printFormat("Error code: 0x{x}\n", .{error_code});
            printFormat("Virtual address: 0x{x}\n", .{virtual_address});
            //printFormat("Physical address: 0x{x}\n", .{arch.paging.getPhysicalAddress(virtual_address)});
        },
        0x0F => {},
        0x10 => {},
        0x11 => {
            printString("Alignment check.\n");
        },
        0x12...0x1F => {},
        0x20 => {
            printString("Timer.\n");
        },
        0x21 => {
            printString("Keyboard pressed.\n");
            keyboard.clearKeyboard();
        },
        0x22...0xFFFFFFFF => {},
    }

    printFormat(" --- Stack Index: {x}\n", .{stack_pointer});

    arch.interrupts.acknowledgeInterrupt();
    arch.interrupts.enableInterrupts();
}
