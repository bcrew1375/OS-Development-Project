const idt = @import("interrupt_descriptor_table.zig");

pub const Interrupts = struct {
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
};
