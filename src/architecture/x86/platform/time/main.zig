const port_io = @import("../io/port_io.zig");

pub fn initializeTimer(frequency: usize) void {
    if (frequency == 0) {
        return;
    }

    const PIT_DIVISOR: u16 = @truncate(1193182 / frequency);
    port_io.out8(0x43, 0b00110100);
    port_io.out8(0x40, @truncate(PIT_DIVISOR & 0xFF));
    port_io.out8(0x40, @truncate(PIT_DIVISOR >> 8));
}
