const arch = @import("arch");

const gdt = @import("../interrupts/global_descriptor_table.zig");
const idt = @import("../interrupts/interrupt_descriptor_table.zig");
const mmu = @import("../mmu/main.zig");

const std = @import("std");

// OS Dev: https://wiki.osdev.org/Zig_Bare_Bones
const MB_HEADER_MAGIC = 0x1BADB002;
const MB_FLAG_ALIGN = 1 << 0;
const MB_FLAG_MEMINFO = 1 << 1;
const FLAGS = MB_FLAG_ALIGN | MB_FLAG_MEMINFO;
const MAX_BOOT_MODULES = 16;

const MultibootHeader = extern struct {
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

const MultibootInfo = extern struct {
    flags: u32,
    mem_lower: u32,
    mem_upper: u32,
    boot_device: u32,
    cmdline_ptr: u32,
    mods_count: u32,
    mods_addr: u32,
    syms_0: u32,
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

const MultibootModule = extern struct {
    mod_start: u32,
    mod_end: u32,
    string: u32,
    reserved: u32,
};

pub var multibootInfo: *MultibootInfo linksection(".multiboot.data") = undefined;

var bootModules: [MAX_BOOT_MODULES]arch.BootModule = undefined;
var bootModuleCount: usize = 0;
var bootModulesCached: bool = false;

var startupStack: [16 * 1024]u8 align(16) linksection(".multiboot.data") = undefined;
var kernelStack: [16 * 1024]u8 align(16) linksection(".bss") = undefined;

extern fn kernelMain() void;

pub export fn _start() linksection(".multiboot.text") callconv(.naked) noreturn {
    asm volatile (
        \\cli
        \\movl %ebx, (%[multibootInfo:P])
        \\mov %[startupStack], %esp
        \\jmp %[kernelSetup:P]
        :
        : [multibootInfo] "i" (&multibootInfo),
          [kernelSetup] "i" (&kernelSetup),
          [startupStack] "i" (@as([*]u8, &startupStack) + startupStack.len),
    );
}

fn kernelSetup() linksection(".multiboot.text") noreturn {
    arch.early_allocator.initialize() catch |err| {
        @panic(@errorName(err));
    };

    reserveBootModules() catch |err| {
        @panic(@errorName(err));
    };

    mmu.initializePaging() catch |err| {
        @panic(@errorName(err));
    };

    asm volatile (
        \\jmp %[higherHalfEntry:P]
        :
        : [higherHalfEntry] "i" (&higherHalfEntry),
    );

    unreachable;
}

fn higherHalfEntry() noreturn {
    asm volatile (
        \\mov %[kernelStack], %esp
        \\call kernelMain
        \\jmp .
        :
        : [kernelStack] "i" (@as([*]u8, &kernelStack) + kernelStack.len),
        : .{
          .ebx = true,
          .esp = true,
        });

    arch.cpu.unrecoverableHalt();
    unreachable;
}

pub fn finishBoot() void {
    cacheBootModules();
    gdt.initialize(@intFromPtr(@as([*]u8, &kernelStack) + kernelStack.len));
    idt.initialize();
    mmu.removeIdentityMapping();
}

pub fn getBootModuleCount() usize {
    ensureBootModulesCached();
    return bootModuleCount;
}

pub fn getBootModule(index: usize) ?arch.BootModule {
    ensureBootModulesCached();
    if (index >= bootModuleCount) {
        return null;
    }
    return bootModules[index];
}

fn ensureBootModulesCached() void {
    if (!bootModulesCached) {
        cacheBootModules();
    }
}

fn cacheBootModules() void {
    if (bootModulesCached) {
        return;
    }

    const available_modules = getAvailableMultibootModuleCount();
    if (available_modules == 0) {
        bootModuleCount = 0;
        bootModulesCached = true;
        return;
    }

    const multiboot_modules = getMultibootModules();

    for (0..available_modules) |module_index| {
        bootModules[module_index] = convertMultibootModule(multiboot_modules[module_index]);
    }

    bootModuleCount = available_modules;
    bootModulesCached = true;
}

fn reserveBootModules() linksection(".multiboot.text") arch.EarlyAllocError!void {
    const available_modules = getAvailableMultibootModuleCount();
    if (available_modules == 0) {
        return;
    }

    const multiboot_modules = getMultibootModules();

    for (0..available_modules) |module_index| {
        const boot_module = convertMultibootModule(multiboot_modules[module_index]);
        if (boot_module.physical_start >= boot_module.physical_end) {
            continue;
        }

        try arch.early_allocator.reserve(
            boot_module.physical_start,
            boot_module.physical_end - boot_module.physical_start,
            arch.ReservedMapRegionType.BOOTLOADER_DATA,
        );
    }
}

fn getAvailableMultibootModuleCount() linksection(".multiboot.text") usize {
    if (multibootInfo.mods_addr == 0) {
        return 0;
    }

    return @min(@as(usize, @intCast(multibootInfo.mods_count)), MAX_BOOT_MODULES);
}

fn getMultibootModules() linksection(".multiboot.text") [*]const MultibootModule {
    return @ptrFromInt(multibootInfo.mods_addr);
}

fn convertMultibootModule(multiboot_module: MultibootModule) linksection(".multiboot.text") arch.BootModule {
    return .{
        .physical_start = multiboot_module.mod_start,
        .physical_end = multiboot_module.mod_end,
    };
}
