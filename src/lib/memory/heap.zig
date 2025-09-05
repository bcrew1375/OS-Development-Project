const kernel_common = @import("../kernel_common.zig");

const std = @import("std");

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

pub fn allocate(heap_struct: *const Heap, size: usize) !*anyopaque {
    const aligned_size = try align_to_block_size(size);
    const total_blocks = aligned_size / BLOCK_SIZE;
    return @ptrFromInt(try allocate_blocks(heap_struct, total_blocks));
}

fn allocate_blocks(heap_struct: *const Heap, blocks: usize) !usize {
    const start_block = try get_start_block(heap_struct, blocks);
    mark_blocks_taken(heap_struct, start_block, blocks);

    const address = block_to_address(heap_struct, start_block);
    return address;
}

//fn free(heap_struct: *const Heap, ptr: *u8) !void {
//    _ = ptr;
//}

fn align_to_block_size(value: usize) !usize {
    if ((value % BLOCK_SIZE) == 0) {
        return value;
    } else {
        return value - (value % BLOCK_SIZE) + BLOCK_SIZE;
    }
}

fn get_start_block(heap_struct: *const Heap, needed_blocks: usize) !usize {
    var current_block: usize = 0;
    var start_block: usize = 0;
    var is_first: bool = true;

    for (0..heap_struct.table.total_entries) |block_entry| {
        if (get_entry_type(heap_struct.table.entries[block_entry]) != BLOCK_FREE) {
            current_block = 0;
            start_block = 0;
            is_first = true;
            continue;
        }

        if (is_first) {
            is_first = false;
            start_block = block_entry;
        }

        current_block += 1;

        if (current_block == needed_blocks) {
            return start_block;
        }
    }

    return HeapError.OutOfMemory;
}

fn get_entry_type(entry_type: u8) u8 {
    return entry_type & 0x0F;
}

fn block_to_address(heap_struct: *const Heap, start_block: usize) usize {
    return @intFromPtr(heap_struct.start_address) + (start_block * BLOCK_SIZE);
}

fn mark_blocks_taken(heap_struct: *const Heap, start_block: usize, total_blocks: usize) void {
    const end_block: usize = start_block + total_blocks - 1;

    var entry: u8 = BLOCK_TAKEN | BLOCK_IS_FIRST;

    if (total_blocks > 1) {
        entry |= BLOCK_HAS_NEXT;
    }

    for (start_block..(end_block + 1)) |block| {
        entry = BLOCK_TAKEN;
        heap_struct.table.entries[block] = entry;
        if (block != end_block) {
            entry |= BLOCK_HAS_NEXT;
        }
    }
}
