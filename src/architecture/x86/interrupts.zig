const interrupts = @import("../architecture.zig").Arch.Interrupts;
const idt = @import("interrupt_descriptor_table.zig");

pub fn Interrupts() interrupts {
    return interrupts{
        .acknowledgeInterrupt = idt.acknowledgeInterrupt,
        
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
};
