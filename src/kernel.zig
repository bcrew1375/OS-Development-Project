const kernel_common = @import("lib/kernel_common.zig");
const paging = @import("lib/memory/paging.zig");
const terminal = @import("lib/terminal.zig");
const std = @import("std");

// OS Dev: https://wiki.osdev.org/Zig_Bare_Bones
const MB_HEADER_MAGIC = 0x1BADB002;
const MB_FLAG_ALIGN = 1 << 0;
const MB_FLAG_MEMINFO = 1 << 1;
const FLAGS = MB_FLAG_ALIGN | MB_FLAG_MEMINFO;

const MultibootHeader = packed struct {
    magic: u32 = MB_HEADER_MAGIC,
    flags: u32 = FLAGS,
    checksum: u32,
    padding: u32 = 0,
};

export var multiboot: MultibootHeader linksection(".multiboot.header") = .{
    // Here we are adding magic and flags and ~ to get 1's complement and by adding 1 we get 2's complement
    .checksum = ~@as(u32, (MB_HEADER_MAGIC + FLAGS)) + 1,
};
// OS Dev: https://wiki.osdev.org/Zig_Bare_Bones

pub export fn _start() linksection(".multiboot.text") callconv(.naked) noreturn {
    asm volatile (
        \\cli
        \\mov $0x400000, %esp
        \\call kernelSetup
        \\jmp .
    );
}

pub export fn kernelSetup() linksection(".multiboot.text") void {
    asm volatile (
    //ICW1: start init, edge triggered, ICW4 needed
        \\mov $0x11, %al
        \\out %al, $0x20
        //ICW2: interrupt vector offset (0x20 = IRQ0 → INT 0x20)
        \\mov $0x20, %al
        \\out %al, $0x21
        //ICW3: bitmask of connected slaves (bit 2 = IRQ2)
        \\mov $0x04, %al
        \\out %al, $0x21
        //ICW4: 8086 mode
        \\mov $0x01, %al
        \\out %al, $0x21
        //End remap of the master PIC.
    );
    paging.setupHigherHalf();
    higherHalfEntry();
}

pub export fn higherHalfEntry() void {
    paging.removeIdentityMapping();

    kernel_common.kernelMain() catch |err| {
        kernel_common.printString(@errorName(err));
    };
}

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, number: ?usize) noreturn {
    terminal.print("\n!KERNEL PANIC!\n");
    terminal.print(message);
    terminal.print("\n");
    _ = stack_trace;
    _ = number;
    while (true) {}
}
