const heap = @import("heap.zig");
const kernel_common = @import("kernel_common");
const std = @import("std");

const KERNEL_HEAP_SIZE_IN_BYTES: usize = 100 * 1024 * 1024;
const KERNEL_HEAP_START_ADDRESS: usize = 0x01000000;
const KERNEL_HEAP_END_ADDRESS: usize = KERNEL_HEAP_START_ADDRESS + KERNEL_HEAP_SIZE_IN_BYTES;

var kernel_heap: heap.Heap = undefined;
pub var kernel_allocator: std.mem.Allocator = undefined;

pub fn initialize() !void {
    kernel_common.printString("Initializing Kernel Heap...\n");

    kernel_heap = heap.Heap.initialize(KERNEL_HEAP_START_ADDRESS, KERNEL_HEAP_SIZE_IN_BYTES);
    kernel_allocator = kernel_heap.allocator();

    kernel_common.printFormat("- Total system RAM: {d}\n", .{KERNEL_HEAP_SIZE_IN_BYTES});
    kernel_common.printFormat("- Heap physical start address: 0x{x}\n", .{KERNEL_HEAP_START_ADDRESS});
    kernel_common.printFormat("- Heap physical end address: 0x{x}\n", .{KERNEL_HEAP_END_ADDRESS});
    kernel_common.printFormat("- Heap total bytes: {d}\n", .{KERNEL_HEAP_SIZE_IN_BYTES});

    kernel_common.printString("- Testing heap allocation of 4096: ");
    const test_one_block_allocate: *[4096]u8 = @ptrCast(try kmalloc(4096));
    test_one_block_allocate[4095] = 55;
    kernel_common.printStringColor("- OK\n", kernel_common.COLOR.GREEN);

    kernel_common.printString("- Testing heap allocation of 8192: ");
    const test_multi_block_allocate: *[8192]u8 = @ptrCast(try kmalloc(8192));
    test_multi_block_allocate[8191] = 85;
    kernel_common.printStringColor("- OK\n", kernel_common.COLOR.GREEN);

    kernel_common.printFormat("- Testing out of heap allocation of: {d}\n", .{KERNEL_HEAP_SIZE_IN_BYTES});
    const alloc_result = kmalloc(KERNEL_HEAP_SIZE_IN_BYTES);
    if (alloc_result) |_| {
        kernel_common.printString("  - Heap allocate failed to detect out of memory. Halting.");
        kernel_common.unrecoverableHalt();
    } else |err| {
        kernel_common.printFormat("  - Heap allocate failed successfully with error: {s}.\n", .{@errorName(err)});
    }

    kernel_common.printStringColor("- OK\n", kernel_common.COLOR.GREEN);
    kernel_common.printStringColor("done\n", kernel_common.COLOR.GREEN);
}

pub fn kmalloc(size: usize) !*anyopaque {
    // Default to 8-byte alignment for general kernel allocations.
    const pointer = try kernel_heap.allocate(size, 8);
    return @ptrCast(pointer);
}
