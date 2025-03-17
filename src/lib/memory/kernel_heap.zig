const heap = @import("heap.zig");

const KERNEL_HEAP_BYTES_SIZE: u32 = 104857600;
const TOTAL_TABLE_ENTRIES: u32 = KERNEL_HEAP_BYTES_SIZE / heap.HEAP_BLOCK_SIZE;
const KERNEL_HEAP_START_ADDRESS: *u8 = @ptrFromInt(0x01000000);
const KERNEL_HEAP_END_ADDRESS: *u8 = @ptrFromInt(@intFromPtr(KERNEL_HEAP_START_ADDRESS) + KERNEL_HEAP_BYTES_SIZE);
const KERNEL_HEAP_TABLE_ADDRESS: *u8 = @ptrFromInt(0x00007E00);

const kernel_heap = heap.Heap{ .start_address = KERNEL_HEAP_START_ADDRESS };
const kernel_heap_table = heap.Table{ .entries = KERNEL_HEAP_TABLE_ADDRESS, .total_entries = TOTAL_TABLE_ENTRIES };

pub fn initialize() !void {
    heap.initialize(&kernel_heap, KERNEL_HEAP_START_ADDRESS, KERNEL_HEAP_END_ADDRESS, &kernel_heap_table) catch |err| {
        return err;
    };
}
