const kernel_common = @import("../kernel_common.zig");

const std = @import("std");

const HEAP_BLOCK_TAKEN: u8 = 0x01;
const HEAP_BLOCK_FREE: u8 = 0x00;

const HEAP_BLOCK_HAS_NEXT: u8 = 0b1000_0000;
const HEAP_BLOCK_IS_FREE: u8 = 0b0100_0000;

pub const HEAP_BLOCK_SIZE: u32 = 4096;

const HeapError = error{
    NotAligned,
    InvalidTableSize,
    OutOfMemory,
};

pub const Table = struct {
    entries: *u8 = undefined,
    total_entries: u32 = 0,
};

pub const Heap = struct {
    table: Table = undefined,
    start_address: *anyopaque = undefined,
};

var local_struct: *const Heap = undefined;
var local_table: *const Table = undefined;

pub fn initialize(heap_struct: *const Heap, start_pointer: *const u8, end_pointer: *const u8, heap_table: *const Table) !void {
    local_struct = heap_struct;
    local_table = heap_table;
    try validate_alignment(start_pointer);
    try validate_alignment(end_pointer);
    try validate_table(start_pointer, end_pointer, local_table);

    // Clear heap memory
    // Clear table memory
}

fn validate_alignment(pointer: *const u8) !void {
    if ((@intFromPtr(pointer) % HEAP_BLOCK_SIZE) != 0) return HeapError.NotAligned;
}

fn validate_table(start_pointer: *const u8, end_pointer: *const u8, table: *const Table) !void {
    const table_size = @intFromPtr(end_pointer) - @intFromPtr(start_pointer);
    const total_blocks = table_size / HEAP_BLOCK_SIZE;

    if (table.total_entries != total_blocks) return HeapError.InvalidTableSize;
}

pub fn allocate(heap_struct: *const Heap, size: usize) !void {
    const aligned_size = align_to_block_size(size);
    const total_blocks = aligned_size / HEAP_BLOCK_SIZE;
    return allocate_blocks(heap_struct, total_blocks);
}

fn allocate_blocks(heap_struct: *const Heap, blocks: usize) !usize {
    var address = 0;
    var start_block = get_start_block(heap_struct, blocks);

    // Check out of memory

    address = block_to_address(heap_struct, start_block);
    mark_blocks_taken(heap_struct, start_block, blocks);
}

fn free(heap_struct: *const Heap, ptr: *u8) !void {
    _ = ptr;
}

fn align_to_block_size(value: usize) !usize {
    if ((value % HEAP_BLOCK_SIZE) == 0) {
        return value;
    } else {
        return value - (value % HEAP_BLOCK_SIZE) + HEAP_BLOCK_SIZE;
    }
}

fn get_start_block(heap_struct: *const Heap, blocks: usize) !void {
    var current_block = 0;
    var free_block = 0;

    for ()
}
