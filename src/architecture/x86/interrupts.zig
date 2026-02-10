const arch = @import("../architecture.zig").Arch.Interrupts;

const interrupts = @import("interrupts/main.zig");

pub fn Interrupts() arch {
    return arch{
        .initialize = interrupts.idt.initialize,
        .set = interrupts.idt.set,
        .enableInterrupts = interrupts.enableInterrupts,
        .disableInterrupts = interrupts.disableInterrupts,
        .acknowledgeInterrupt = interrupts.acknowledgeInterrupt,
    };
}
