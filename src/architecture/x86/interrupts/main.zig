const arch = @import("arch");
const console = arch.platform;

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
    // Only acknowledge hardware interrupts (IRQs)
    // Assuming IRQs are remapped to 0x20 - 0x2F
    if (vector >= 0x20 and vector <= 0x2F) {
        if (vector >= 0x28) {
            port_io.out8(0xA0, 0x20); // EOI to Slave
        }
        port_io.out8(0x20, 0x20); // EOI to Master
    }
}

pub export fn interruptHandler(vector: usize, stack_pointer: usize) callconv(.c) void {
    // Not ready to handle nested interrupts. Don't risk stack overflow.
    //arch.interrupts.disableInterrupts();
    console.print("Interrupt: ");
    switch (vector) {
        0x00 => {
            console.print("Divide by zero.\n");
        },
        0x01 => {
            console.print("Debug exception.\n");
        },
        0x02...0x05 => {},
        0x06 => {
            console.print("Invalid opcode.\n");
        },
        0x07 => {},
        0x08 => {
            console.print("Double fault.\n");
        },
        0x09 => {},
        0x0A => {
            console.print("Invalid TSS.\n");
        },
        0x0B => {},
        0x0C => {
            console.print("Stack segment fault.\n");
        },
        0x0D => {
            console.print("General protection fault.\n");
            //console.writer.print(" Stack Index: {x}\n", .{stack_pointer}) catch {};
            //arch.cpu.unrecoverableHalt();
        },
        0x0E => {
            // const stack_array: *[4]usize = @ptrFromInt(stack_pointer);
            // const error_code: usize = stack_array[0];
            // const virtual_address: usize = stack_array[1];
            // console.print("Page fault.\n");
            // console.writer.print("Error code: 0x{x}\n", .{error_code}) catch {};
            // console.writer.print("Virtual address: 0x{x}\n", .{virtual_address}) catch {};
            //printFormat("Physical address: 0x{x}\n", .{arch.paging.getPhysicalAddress(virtual_address)});
        },
        0x0F => {},
        0x10 => {},
        0x11 => {
            console.print("Alignment check.\n");
        },
        0x12...0x1F => {},
        0x20 => {
            console.print("Timer.\n");
        },
        0x21 => {
            console.print("Keyboard pressed.\n");
            keyboard.clearKeyboard();
        },
        0x22...0xFFFFFFFF => {},
    }

    // console.writer.print(" --- Stack Index: {x}\n", .{stack_pointer}) catch {};
    _ = stack_pointer;

    acknowledgeInterrupt(vector);
    enableInterrupts();
}
