const arch = @import("arch");

// const gdt = @import("../interrupts/global_descriptor_table.zig");
// const idt = @import("../interrupts/interrupt_descriptor_table.zig");
// const mmu = @import("../mmu/main.zig");
const limine = @import("limine/main.zig");
const boot_modules = @import("limine/boot_modules.zig");

comptime {
    _ = limine.requests_start_marker;
    _ = limine.hhdm_request;
    _ = limine.memory_map_request;
    _ = limine.module_request;
    _ = limine.requests_end_marker;
    _ = limine._start;
}

pub const getBootModule = boot_modules.getBootModule;
pub const getBootModuleCount = boot_modules.getBootModuleCount;

const std = @import("std");

extern const _startup_stack_start: usize;
extern const _startup_stack_end: usize;

extern fn kernelMain() void;

pub fn kernelSetup() noreturn {
    arch.early_allocator.initialize() catch |err| {
        @panic(@errorName(err));
    };

    boot_modules.reserveBootModules() catch |err| {
        @panic(@errorName(err));
    };

    // mmu.initializePaging() catch |err| {
    //     @panic(@errorName(err));
    // };

    boot_modules.cacheBootModules();
    kernelMain();

    arch.cpu.unrecoverableHalt();
    unreachable;
}

pub fn finishBoot() void {
    // gdt.initialize(...);
    // idt.initialize();
    //mmu.removeIdentityMapping();
}
