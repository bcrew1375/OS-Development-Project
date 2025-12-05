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
        \\mov $0x300000, %esp
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

        \\call higherHalfSetup
        \\jmp .
    );
}

pub export fn higherHalfSetup() linksection(".multiboot.text") void {
    paging.enablePaging();
    setupGDT();
    kernelMain();
}

pub export fn kernelMain() void {
    paging.removeIdentityEntry();
    kernel_common.kernelInitialize() catch |err| {
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

fn setupGDT() void {
    const GlobalDescriptorTable = packed struct {
        null_1: u32 = 0,
        null_2: u32 = 0,

        code_limit: u16 = 0xffff,
        code_base_low: u24 = 0,
        code_access: u8 = 0x9a,
        code_flags: u8 = 0b11001111,
        code_base_high: u8 = 0,

        data_limit: u16 = 0xffff,
        data_base_low: u24 = 0,
        data_access: u8 = 0x92,
        data_flags: u8 = 0b11001111,
        data_base_high: u8 = 0,

        tss_limit: u16 = undefined,
        tss_base_low: u24 = undefined,
        tss_access: u8 = 0x89,
        tss_flags: u8 = 0x00,
        tss_high: u8 = undefined,
    };

    const GlobalDescriptorTableRegister = packed struct {
        size: u16 = undefined,
        address: u32 = undefined,
    };

    var tss: [104]u8 = undefined;
    const tss_address = @intFromPtr(&tss);

    var gdt = GlobalDescriptorTable{ .tss_limit = 103, .tss_base_low = @truncate(tss_address & 0x00FFFFFF), .tss_high = @truncate(tss_address >> 24) };

    const gdtr = GlobalDescriptorTableRegister{ .address = @intFromPtr(&gdt), .size = @sizeOf(GlobalDescriptorTable) - 1 };

    asm volatile (
        \\lgdt (%ecx)
        \\
        \\mov $0x10, %ax
        \\mov %ax, %ds
        \\mov %ax, %es
        \\mov %ax, %fs
        \\mov %ax, %ss
        :
        : [gdtr] "{ecx}" (&gdtr),
        : .{ .ecx = true, .memory = true });
}
