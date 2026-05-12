const arch = @import("arch");
const kernel_common = @import("kernel_common");
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
    console.writer.writeAll("Interrupt: ") catch {};
    switch (vector) {
        0x00 => {
            console.writer.writeAll("Divide by zero.\n") catch {};
        },
        0x01 => {
            console.writer.writeAll("Debug exception.\n") catch {};
        },
        0x02...0x05 => {},
        0x06 => {
            console.writer.writeAll("Invalid opcode.\n") catch {};
        },
        0x07 => {},
        0x08 => {
            console.writer.writeAll("Double fault.\n") catch {};
        },
        0x09 => {},
        0x0A => {
            console.writer.writeAll("Invalid TSS.\n") catch {};
        },
        0x0B => {},
        0x0C => {
            console.writer.writeAll("Stack segment fault.\n") catch {};
        },
        0x0D => {
            console.writer.writeAll("General protection fault.\n") catch {};
            console.writer.print(" Stack Index: 0x{x}\n", .{stack_pointer}) catch {};
        },
        0x0E => {
            const virtual_address = asm volatile ("mov %%cr2, %[out]"
                : [out] "=r" (-> u32),
            );
            const stack_array: *[1]usize = @ptrFromInt(stack_pointer);
            const error_code: usize = stack_array[0];
            const fault_info = arch.FaultInfo{
                .address = virtual_address,
                .present = (error_code & 0x1) != 0,
                .write = (error_code & 0x2) != 0,
                .user = (error_code & 0x4) != 0,
                // .reserved       = (error_code & 0x8)  != 0,
                .instruction_fetch = (error_code & 0x10) != 0,
                // .protection_key = (error_code & 0x20) != 0,
                // .shadow_stack   = (error_code & 0x40) != 0,
            };
            kernel_common.vmm.faultHandler(fault_info);
            //printFormat("Physical address: 0x{x}\n", .{arch.paging.getPhysicalAddress(virtual_address)});
        },
        0x0F => {},
        0x10 => {},
        0x11 => {
            console.writer.writeAll("Alignment check.\n") catch {};
        },
        0x12...0x1F => {},
        0x20 => {
            console.writer.writeAll("Timer.\n") catch {};
        },
        0x21 => {
            console.writer.writeAll("Keyboard pressed.\n") catch {};
            keyboard.clearKeyboard();
        },
        0x22...0xFFFFFFFF => {},
    }

    console.writer.print(" --- Stack Index: {x}\n", .{stack_pointer}) catch {};

    acknowledgeInterrupt(vector);
}
