const std = @import("std");

const kernel_common = @import("../kernel_common.zig");
const paging = @import("./paging.zig");

const BLOCK_TAKEN: u8 = 0b0000_0001;
const BLOCK_FREE: u8 = 0b0000_0000;

const BLOCK_HAS_NEXT: u8 = 0b1000_0000;
const BLOCK_IS_FIRST: u8 = 0b0100_0000;

pub const BLOCK_SIZE: u32 = 4096;

pub const HeapError = error{
    NotAligned,
    InvalidTableSize,
    OutOfMemory,
    IntegrityError,
};

pub const Table = struct {
    entries: []u8 = undefined,
    total_entries: u32 = 0,
};

pub const Heap = struct {
    table: Table = undefined,
    start_address: *anyopaque = undefined,
};

pub fn initialize(heap_struct: *const Heap, start_pointer: *const u8, end_pointer: *const u8) !void {
    try validate_alignment(start_pointer);
    try validate_alignment(end_pointer);
    try validate_table(heap_struct, start_pointer, end_pointer);

    // Clear heap memory
    // Clear table memory
}

fn validate_alignment(pointer: *const u8) !void {
    if ((@intFromPtr(pointer) % BLOCK_SIZE) != 0) return HeapError.NotAligned;
}

fn validate_table(heap_struct: *const Heap, start_pointer: *const u8, end_pointer: *const u8) !void {
    const table_size = @intFromPtr(end_pointer) - @intFromPtr(start_pointer);
    const total_blocks = table_size / BLOCK_SIZE;

    if (heap_struct.table.total_entries != total_blocks) return HeapError.InvalidTableSize;
}
