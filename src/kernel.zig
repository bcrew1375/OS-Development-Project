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

    vmm.setAddressSpace(&kernelAddressSpace);

    const direct_map_start_address = arch.mmu.getDirectMapVirtualAddress();
    const available_ram = arch.mmu.getMaxAvailableAddress();

    const direct_map_size = @min(@as(u64, arch.mmu.getDirectMapMaxSize()), available_ram);
    const direct_map_end_address = direct_map_start_address + @as(usize, @intCast(direct_map_size));

    vmm.map(&kernelAddressSpace, direct_map_start_address, direct_map_end_address, core_memory_permissions) catch |err| {
        arch.platform.setColor(TextColor.RED);
        arch.platform.writer().print("Kernel core address space init failed with error: {s}\n", .{@errorName(err)}) catch {};
        arch.cpu.unrecoverableHalt();
    };

    const kernel_heap_start_address = arch.mmu.getKernelHeapVirtualAddress();
    const kernel_heap_end_address = kernel_heap_start_address + arch.mmu.getKernelHeapSize();

    vmm.map(&kernelAddressSpace, kernel_heap_start_address, kernel_heap_end_address, heap_memory_permissions) catch |err| {
        arch.platform.setColor(TextColor.RED);
        arch.platform.writer().print("Kernel heap address space init failed with error: {s}\n", .{@errorName(err)}) catch {};
        arch.cpu.unrecoverableHalt();
    };

    terminal.print.printString("Initializing kernel heap...");
    // Initialize heap here.
    terminal.print.printStringColor("done!\n", TextColor.GREEN);

    terminal.print.printString("Initializing PMM...");
    pmm.initialize() catch |err| {
        arch.platform.setColor(TextColor.RED);
        arch.platform.writer().print("PMM init failed with error: {s}\n", .{@errorName(err)}) catch {};
        arch.cpu.unrecoverableHalt();
    };
    terminal.print.printStringColor("done!\n", TextColor.GREEN);

    arch.boot.finishBoot();

    terminal.print.printString("Initializing interrupts...");
    arch.interrupts.initialize();
    terminal.print.printStringColor("done!\n", TextColor.GREEN);

    try arch.platform.writer().print("Total Available RAM: {d} KB\n", .{pmm.getTotalAvailableRAM() / 1024});
    try arch.platform.writer().print("Total System Reserved RAM: {d} KB\n", .{pmm.getTotalSystemReservedRAM() / 1024});

    //arch.platform.initializeTimer(10);

    arch.interrupts.enableInterrupts();
    //arch.cpu.unrecoverableHalt();
}

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, number: ?usize) noreturn {
    arch.interrupts.disableInterrupts();
    arch.platform.setColor(TextColor.RED);
    arch.platform.writer().writeAll("\n!KERNEL PANIC!\n") catch {};
    arch.platform.writer().writeAll(message) catch {};
    arch.platform.writer().writeAll("\n") catch {};
    _ = stack_trace;
    _ = number;
    while (true) {}
}
