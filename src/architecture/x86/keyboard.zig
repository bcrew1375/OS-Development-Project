const port_io = @import("port_io.zig");

pub fn clearKeyboard() void {
    _ = port_io.in8(0x60);
}
