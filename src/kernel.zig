const arch = @import("arch");
const pmm = @import("kernel_common").pmm;
const vmm = @import("kernel_common").vmm;
const terminal = @import("kernel_common").terminal;
const TextColor = @import("arch").TextColor;

const std = @import("std");

const KERNEL_VMA_TOTAL = 2;

var kernelVmaBacking: [KERNEL_VMA_TOTAL]vmm.VirtualMemoryArea = undefined;

var kernelAddressSpace: vmm.AddressSpace = vmm.AddressSpace{
    .VMAList = &kernelVmaBacking,
    .length = 0,
};

pub export fn kernelMain() void {
    terminal.initialize();

    terminal.print.printString("Initializing PMM...");
    pmm.initialize() catch |err| {
        arch.platform.setColor(TextColor.RED);
        arch.platform.writer.print("PMM init failed with error: {s}\n", .{@errorName(err)}) catch {};
        arch.cpu.unrecoverableHalt();
    };
    terminal.print.printStringColor("done!\n", TextColor.GREEN);
    arch.boot.finishBoot();

    terminal.print.printString("Initializing interrupts...");
    arch.interrupts.initialize();
    terminal.print.printStringColor("done!\n", TextColor.GREEN);
    arch.interrupts.enableInterrupts();

    arch.platform.initializeTimer(100);

    const core_memory_permissions = vmm.MemoryPermissions{
        .readable = true,
        .writeable = false,
        .executable = true,
        .user_accessible = false,
    };

    const heap_memory_permissions = vmm.MemoryPermissions{
        .readable = true,
        .writeable = true,
        .executable = true,
        .user_accessible = false,
    };

    vmm.initialize(&kernelAddressSpace);

    vmm.map(&kernelAddressSpace, arch.mmu.getKernelCoreAddress(), arch.mmu.getKernelCoreAddress() + 0x10000000, core_memory_permissions) catch |err| {
        arch.platform.setColor(TextColor.RED);
        arch.platform.writer.print("Kernel core address space init failed with error: {s}\n", .{@errorName(err)}) catch {};
        arch.cpu.unrecoverableHalt();
    };

    vmm.map(&kernelAddressSpace, arch.mmu.getKernelHeapAddress(), arch.mmu.getKernelHeapAddress() + 0x10000000, heap_memory_permissions) catch |err| {
        arch.platform.setColor(TextColor.RED);
        arch.platform.writer.print("Kernel heap address space init failed with error: {s}\n", .{@errorName(err)}) catch {};
        arch.cpu.unrecoverableHalt();
    };

    // vmm.map(&kernelAddressSpace, 0xF0000000, 0xFFFFFFFF, heap_memory_permissions) catch |err| {
    //     arch.platform.setColor(TextColor.RED);
    //     arch.platform.writer.print("Kernel heap address space init failed with error: {s}\n", .{@errorName(err)}) catch {};
    //     arch.cpu.unrecoverableHalt();
    // };

    try arch.platform.writer.print("Total Available RAM: {d} KB\n", .{pmm.getTotalAvailableRAM() / 1024});
    try arch.platform.writer.print("Total System Reserved RAM: {d} KB\n", .{pmm.getTotalSystemReservedRAM() / 1024});

    const page_fault: *usize = @ptrFromInt(0xD0000000);
    page_fault.* = 5;

    arch.cpu.unrecoverableHalt();

    // kernel_heap.initialize() catch |err| {
    //     printString(@errorName(err));
    //     unrecoverableHalt();
    // };
    // disableInterrupts();
    // paging.makePageDirectory(0x03) catch |err| {
    //     printString(@errorName(err));
    //     unrecoverableHalt();
    // };
}

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, number: ?usize) noreturn {
    arch.interrupts.disableInterrupts();
    arch.platform.setColor(TextColor.RED);
    arch.platform.writer.writeAll("\n!KERNEL PANIC!\n") catch {};
    arch.platform.writer.writeAll(message) catch {};
    arch.platform.writer.writeAll("\n") catch {};
    _ = stack_trace;
    _ = number;
    while (true) {}
}
