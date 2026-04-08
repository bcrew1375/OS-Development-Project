const gdt = @import("../interrupts/global_descriptor_table.zig");
const idt = @import("../interrupts/interrupt_descriptor_table.zig");
const mmu = @import("../mmu/main.zig");
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

export var multiboot_header: MultibootHeader align(32) linksection(".multiboot.header") = .{
    // Here we are adding magic and flags and ~ to get 1's complement and by adding 1 we get 2's complement
    .checksum = ~@as(u32, (MB_HEADER_MAGIC + FLAGS)) + 1,
};
// OS Dev: https://wiki.osdev.org/Zig_Bare_Bones

const MultibootInfo = packed struct {
    flags: u32,
    mem_lower: u32,
    mem_upper: u32,
    boot_device: u32,
    cmdline: u32,
    mods_count: u32,
    mods_addr: u32,
    syms_1: u32,
    syms_2: u32,
    syms_3: u32,
    mmap_length: u32,
    mmap_addr: u32,
    drives_length: u32,
    drives_addr: u32,
    config_table: u32,
    boot_loader_name: u32,
    apm_table: u32,
    vbe_control_info: u32,
    vbe_mode_info: u32,
    vbe_mode: u16,
    vbe_interface_seg: u16,
    vbe_interface_off: u16,
    vbe_interface_len: u16,
    framebuffer_addr_low: u32,
    framebuffer_addr_high: u16,
    framebuffer_pitch: u32,
    framebuffer_width: u32,
    framebuffer_height: u32,
    framebuffer_bpp: u32,
    framebuffer_type: u32,
    color_info: u32,
    color_info_1: u8,
};

pub var multiboot_info: *MultibootInfo linksection(".multiboot.data") = undefined;

var startup_stack: [1024]u8 align(16) linksection(".multiboot.text") = undefined;
var kernel_stack: [8192]u8 align(16) = undefined;

extern fn kernelMain() void;

pub export fn _start() linksection(".multiboot.text") callconv(.naked) noreturn {
    asm volatile (
        \\cli
        \\mov %[startup_stack], %esp
        \\jmp kernelSetup
        :
        : [startup_stack] "i" (@as([*]u8, &startup_stack) + startup_stack.len),
    );
}

export fn kernelSetup() linksection(".multiboot.text") callconv(.naked) noreturn {
    asm volatile (
        \\movl %ebx, (%[multiboot_info:P])
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
        \\call (%[mmu_initialize:P])
        \\jmp higherHalfEntry
        :
        : [mmu_initialize] "i" (&mmu.initialize),
          [multiboot_info] "i" (&multiboot_info),
        : .{
          .eax = true,
          .memory = true,
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

pub fn finishBoot() void {
    //time.setupTimer();
    gdt.initialize();
    mmu.removeIdentityMapping();
    idt.initialize();
}
