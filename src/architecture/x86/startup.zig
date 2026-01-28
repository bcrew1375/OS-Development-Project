//const arch = @import("architecture.zig");
const gdt = @import("global_descriptor_table.zig");
const idt = @import("interrupt_descriptor_table.zig");
const time = @import("time.zig");
const paging = @import("paging.zig");
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

extern fn kernelMain() void;

export var multiboot: MultibootHeader linksection(".multiboot.header") = .{
    // Here we are adding magic and flags and ~ to get 1's complement and by adding 1 we get 2's complement
    .checksum = ~@as(u32, (MB_HEADER_MAGIC + FLAGS)) + 1,
};
// OS Dev: https://wiki.osdev.org/Zig_Bare_Bones

var startup_stack: [1024]u8 align(16) linksection(".multiboot.text") = undefined;
var kernel_stack: [8192]u8 align(16) = undefined;

pub export fn _start() linksection(".multiboot.text") callconv(.naked) noreturn {
    asm volatile (
        \\cli
        \\mov %[startup_stack], %esp
        \\jmp kernelSetup
        :
        : [startup_stack] "i" (@as([*]u8, &startup_stack) + startup_stack.len),
    );
}

pub const Startup = struct {
    pub fn finishStartup() !void {
        time.setupTimer();
        gdt.initialize();
        paging.removeIdentityMapping();
        idt.initialize();
    }
};

export fn kernelSetup() linksection(".multiboot.text") callconv(.naked) noreturn {
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
        \\call *%[paging_initialize]
        \\jmp higherHalfEntry
        :
        : [paging_initialize] "{ebx}" (paging.initialize),
        : .{
          .eax = true,
          .ebx = true,
        });
}

export fn higherHalfEntry() callconv(.naked) noreturn {
    asm volatile (
        \\mov %[kernel_stack], %esp
        \\call kernelMain
        \\jmp .
        :
        : [kernel_stack] "i" (@as([*]u8, &kernel_stack) + kernel_stack.len),
        : .{
          .ebx = true,
          .esp = true,
        });
}
