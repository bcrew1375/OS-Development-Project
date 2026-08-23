const port_io = @import("port_io.zig");
const std = @import("std");

const com1_base_address: u16 = 0x3F8;

const PortOffset = enum(u16) {
    data = 0,
    interrupt_enable = 1,
    fifo_control = 2,
    line_control = 3,
    modem_control = 4,
    line_status = 5,
};

/// Initializes the COM1 serial port to 38400 baud, 8N1.
pub fn initialize() void {
    // Disable all interrupts
    port_io.out8(com1_base_address + @intFromEnum(PortOffset.interrupt_enable), 0x00);
    // Enable DLAB (set baud rate divisor)
    port_io.out8(com1_base_address + @intFromEnum(PortOffset.line_control), 0x80);
    // Set divisor to 3 (38400 baud)
    port_io.out8(com1_base_address + @intFromEnum(PortOffset.data), 0x03);
    port_io.out8(com1_base_address + @intFromEnum(PortOffset.interrupt_enable), 0x00);
    // 8 bits, no parity, one stop bit
    port_io.out8(com1_base_address + @intFromEnum(PortOffset.line_control), 0x03);
    // Enable FIFO, clear them, with 14-byte threshold
    port_io.out8(com1_base_address + @intFromEnum(PortOffset.fifo_control), 0xC7);
    // IRQs enabled, RTS/DSR set
    port_io.out8(com1_base_address + @intFromEnum(PortOffset.modem_control), 0x0B);
}

fn isTransmitHoldingRegisterEmpty() bool {
    return (port_io.in8(com1_base_address + @intFromEnum(PortOffset.line_status)) & 0x20) != 0;
}

/// Sends a single character over the serial port.
pub fn writeCharacter(character: u8) void {
    while (!isTransmitHoldingRegisterEmpty()) {}
    port_io.out8(com1_base_address, character);
}

/// Sends a string over the serial port.
pub fn writeString(string: []const u8) void {
    for (string) |character| {
        writeCharacter(character);
    }
}

const Writer = std.io.GenericWriter(void, error{}, struct {
    fn write(_: void, data: []const u8) error{}!usize {
        writeString(data);
        return data.len;
    }
}.write);

/// Returns a Zig std.io.Writer instance for serial output.
pub fn writer() Writer {
    return .{ .context = {} };
}
