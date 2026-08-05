const arch = @import("arch");

const gdt = @import("../interrupts/global_descriptor_table.zig");
const idt = @import("../interrupts/interrupt_descriptor_table.zig");
const mmu = @import("../mmu/main.zig");
const multiboot = @import("multiboot/main.zig");
const multiboot_modules = @import("multiboot/boot_modules.zig");

pub const getBootModule = multiboot_modules.getBootModule;
pub const getBootModuleCount = multiboot_modules.getBootModuleCount;

const std = @import("std");

extern const _startup_stack_start: usize;
extern const _startup_stack_end: usize;

var kernelStack: [16 * 1024]u8 align(16) linksection(".bss") = undefined;

extern fn kernelMain() void;
const modules: [*]const multiboot_modules.MultibootModule linksection(".multiboot.data") = @ptrFromInt(0x18E000);

pub fn kernelSetup() linksection(".multiboot.text") noreturn {
    arch.early_allocator.initialize() catch |err| {
        @panic(@errorName(err));
    };

    _ = modules;

    multiboot_modules.reserveBootModules() catch |err| {
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
    multiboot_modules.cacheBootModules();
    gdt.initialize(@intFromPtr(@as([*]u8, &kernelStack) + kernelStack.len));
    idt.initialize();
    mmu.removeIdentityMapping();
}
