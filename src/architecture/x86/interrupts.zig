const interrupts = @import("../architecture.zig").Arch.Interrupts;
const idt = @import("interrupt_descriptor_table.zig");
const port_io = @import("port_io.zig");

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
