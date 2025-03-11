const kernel_common = @import("../kernel_common.zig");

const HEAP_BLOCK_TAKEN: u8 = 0x01;
const HEAP_BLOCK_FREE: u8 = 0x00;
const HEAP_BLOCK_HAS_NEXT: u8 = 0b1000_0000;

pub fn initialize() void {
    const heap: u8 = HEAP_BLOCK_FREE + HEAP_BLOCK_HAS_NEXT + HEAP_BLOCK_TAKEN;
    _ = heap;
}
