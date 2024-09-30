const idt = @import("idt/interrupt_descriptor_table.zig");
const terminal = @import("terminal.zig");

pub const KERNEL_CODE_SELECTOR: u8 = 0x08;
pub const KERNEL_DATA_SELECTOR: u8 = 0x10;

pub fn kernelInitialize() void {
    idt.initialize();
}

pub fn printError(string: []const u8) void {
    terminal.print(string);
}
