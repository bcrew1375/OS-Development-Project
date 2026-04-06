const terminal = @import("kernel_common").terminal;

pub const idt = @import("interrupt_descriptor_table.zig");
pub const port_io = @import("../platform/io/port_io.zig");
const keyboard = @import("../platform/io/keyboard.zig");

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

pub fn acknowledgeInterrupt(vector: usize) void {
    _ = vector;
    port_io.out8(0x20, 0x20);
    port_io.out8(0xA0, 0x20);
}

pub export fn interruptHandler(vector: usize, stack_pointer: usize) callconv(.c) void {
    // Not ready to handle nested interrupts. Don't risk stack overflow.
    //arch.interrupts.disableInterrupts();
    terminal.printString("Interrupt: ");
    switch (vector) {
        0x00 => {
            terminal.printString("Divide by zero.\n");
        },
        0x01 => {
            terminal.printString("Debug exception.\n");
        },
        0x02...0x05 => {},
        0x06 => {
            terminal.printString("Invalid opcode.\n");
        },
        0x07 => {},
        0x08 => {
            terminal.printString("Double fault.\n");
        },
        0x09 => {},
        0x0A => {
            terminal.printString("Invalid TSS.\n");
        },
        0x0B => {},
        0x0C => {
            terminal.printString("Stack segment fault.\n");
        },
        0x0D => {
            terminal.printString("General protection fault.\n");
            terminal.printFormat(" Stack Index: {x}\n", .{stack_pointer});
            //arch.cpu.unrecoverableHalt();
        },
        0x0E => {
            const stack_array: *[4]usize = @ptrFromInt(stack_pointer);
            const error_code: usize = stack_array[0];
            const virtual_address: usize = stack_array[1];
            terminal.printString("Page fault.\n");
            terminal.printFormat("Error code: 0x{x}\n", .{error_code});
            terminal.printFormat("Virtual address: 0x{x}\n", .{virtual_address});
            //printFormat("Physical address: 0x{x}\n", .{arch.paging.getPhysicalAddress(virtual_address)});
        },
        0x0F => {},
        0x10 => {},
        0x11 => {
            terminal.printString("Alignment check.\n");
        },
        0x12...0x1F => {},
        0x20 => {
            terminal.printString("Timer.\n");
        },
        0x21 => {
            terminal.printString("Keyboard pressed.\n");
            keyboard.clearKeyboard();
        },
        0x22...0xFFFFFFFF => {},
    }

    terminal.printFormat(" --- Stack Index: {x}\n", .{stack_pointer});

    acknowledgeInterrupt(vector);
    enableInterrupts();
}
