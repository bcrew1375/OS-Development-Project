const paging = @import("paging.zig");

// Assume 4 GB of physical RAM for now.
// 4 GB / 4096 frame size = 1 MB.
const NUMBER_OF_FRAMES: usize = 1048576;

const PmmError = error{
    OutOfMemory,
};

var allocationBitmap: [NUMBER_OF_FRAMES]bool = undefined;

const kernelBaseFramesCount = 1024;

pub fn initialize() void {
    for (0..kernelBaseFramesCount) |frame| {
        allocationBitmap[frame] = 1;
    }
}

pub fn allocate(needed_blocks: u32) !u32 {
    const start_block = try get_start_block(needed_blocks);
    mark_blocks_taken(start_block, needed_blocks);
}

pub fn free(frame: u32) !void {
    // First 4 MBs are kernel base and off limits.
    if ((frame >= kernelBaseFramesCount) and (frame < allocationBitmap.len)) {
        allocationBitmap[frame] = 0;
    }
}

fn get_start_block(needed_blocks: usize) !usize {
    var current_block: usize = 0;
    var start_block: usize = 0;
    var is_first: bool = true;

    for (0..NUMBER_OF_FRAMES) |block_entry| {
        if (get_entry_type(allocationBitmap[block_entry]) != 1) {
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

    return PmmError.OutOfMemory;
}

fn allocate_blocks(blocks: usize) !usize {
    const start_block = try get_start_block(blocks);
    mark_blocks_taken(start_block, blocks);
}

fn mark_blocks_taken(start_block: usize, total_blocks: usize) void {
    const end_block: usize = start_block + total_blocks - 1;

    for (start_block..(end_block + 1)) |block| {
        allocationBitmap[block] = true;
    }
}
