const port_io = @import("port_io.zig");

pub fn unrecoverableHalt() noreturn {
    asm volatile (
        \\cli
        \\hlt
    );
    unreachable;
}

pub fn setupTimer() void {
    //Set 100 Hz PIT divisor. 1193182 / 100 = ~100 Hz
    const PIT_DIVISOR: u16 = 65535;
    port_io.out8(0x43, 0b00110100);
    port_io.out8(0x40, @truncate(PIT_DIVISOR & 0xFF));
    port_io.out8(0x40, @truncate(PIT_DIVISOR >> 8));
}
