const kernel_common = @import("../kernel_common.zig");

const HEAP_BLOCK_TAKEN: u8 = 0x01;
const HEAP_BLOCK_FREE: u8 = 0x00;

const HEAP_BLOCK_HAS_NEXT: u8 = 0b1000_0000;
const HEAP_BLOCK_IS_FREE: u8 = 0b0100_0000;

pub const HEAP_BLOCK_SIZE: u32 = 4096;

const HeapError = error{
    NotAligned,
};

pub const Table = struct {
    entries: *u8 = undefined,
    total_entries: u32 = 0,
};

pub const Heap = struct {
    table: Table = undefined,
    start_address: *anyopaque = undefined,
};

pub fn initialize(heap_struct: *const Heap, start_pointer: *const u8, end_pointer: *const u8, table: *const Table) !void {
    _ = heap_struct;
    _ = table;
    try validate_alignment(start_pointer);
    try validate_alignment(end_pointer);
    //return HeapError.NotAligned;
}

fn validate_alignment(pointer: *const u8) !void {
    if ((@intFromPtr(pointer) % HEAP_BLOCK_SIZE) != 0) return error.NotAligned;
}
