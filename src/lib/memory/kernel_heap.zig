const heap = @import("heap.zig");
const kernel_common = @import("../kernel_common.zig");

const KERNEL_HEAP_BYTES_SIZE: u32 = 104857600;
const TOTAL_TABLE_ENTRIES: u32 = KERNEL_HEAP_BYTES_SIZE / heap.BLOCK_SIZE;
const KERNEL_HEAP_TABLE_ADDRESS: *[TOTAL_TABLE_ENTRIES]u8 = @ptrFromInt(0x00007E00);
const KERNEL_HEAP_START_ADDRESS: *u8 = @ptrFromInt(0x01000000);
const KERNEL_HEAP_END_ADDRESS: *u8 = @ptrFromInt(@intFromPtr(KERNEL_HEAP_START_ADDRESS) + KERNEL_HEAP_BYTES_SIZE);

const kernel_heap = heap.Heap{ .start_address = KERNEL_HEAP_START_ADDRESS, .table = heap.Table{ .entries = KERNEL_HEAP_TABLE_ADDRESS, .total_entries = TOTAL_TABLE_ENTRIES } };

pub fn initialize() !void {
    kernel_common.printString("Initializing Kernel Heap...\n");
    heap.initialize(&kernel_heap, KERNEL_HEAP_START_ADDRESS, KERNEL_HEAP_END_ADDRESS) catch |err| {
        return err;
    };
    kernel_common.printFormat("- Total heap blocks: {d}\n", .{TOTAL_TABLE_ENTRIES});
    kernel_common.printFormat("- Heap table start address: 0x{x}\n", .{@intFromPtr(KERNEL_HEAP_TABLE_ADDRESS)});
    kernel_common.printFormat("- Heap physical start address: 0x{x}\n", .{@intFromPtr(KERNEL_HEAP_START_ADDRESS)});
    kernel_common.printFormat("- Heap physical end address: 0x{x}\n", .{@intFromPtr(KERNEL_HEAP_END_ADDRESS)});
    kernel_common.printFormat("- Heap total bytes: {d}\n", .{KERNEL_HEAP_BYTES_SIZE});
    kernel_common.printString("- Testing heap allocation of 50: ");
    const test_one_block_allocate: *[50]u8 = @ptrCast(try kmalloc(50));
    test_one_block_allocate[49] = 55;
    kernel_common.printString("- OK\n");
    kernel_common.printString("- Testing heap allocation of 5000: ");
    const test_multi_block_allocate: *[5000]u8 = @ptrCast(try kmalloc(5000));
    test_multi_block_allocate[4999] = 85;
    kernel_common.printString("- OK\n");
    kernel_common.printFormat("- Testing out of heap allocation of: {d}\n", .{KERNEL_HEAP_BYTES_SIZE});
    _ = kmalloc(KERNEL_HEAP_BYTES_SIZE) catch |err| {
        kernel_common.printFormat("  - Heap allocate failed successfully with: {s} ", .{@errorName(err)});
    };
    kernel_common.printString("- OK\n");

    kernel_common.printStringColor("done\n", kernel_common.COLOR.GREEN);
}

pub fn kmalloc(size: usize) !*anyopaque {
    return try heap.allocate(&kernel_heap, size);
}
