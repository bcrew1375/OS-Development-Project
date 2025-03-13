const kernel_common = @import("../kernel_common.zig");

const HEAP_BLOCK_TAKEN: u8 = 0x01;
const HEAP_BLOCK_FREE: u8 = 0x00;

const HEAP_BLOCK_HAS_NEXT: u8 = 0b1000_0000;
const HEAP_BLOCK_IS_FREE: u8 = 0b0100_0000;

const table = struct {
    table_entry: [*]u8 = undefined,
    total_entries: u32 = 0,
};

const heap = struct {
    table: table = undefined,
    start_address: anyopaque = undefined,
};

pub fn initialize() !void {
    return error.NotImplemented;
}
