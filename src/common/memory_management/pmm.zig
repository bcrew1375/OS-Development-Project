// Assume 128 MBs of physical RAM for now.
// 128 MBs / 4096 frame size = 32 KBs.
pub const TOTAL_NUMBER_OF_FRAMES: u16 = 32768;

// Reserve the first 4 MBs for the kernel and hardware.
pub const KERNEL_BASE_FRAMES_COUNT: u16 = 1024;

pub const PmmError = error{
    OutOfMemory,
    InvalidSize,
    InvalidIndex,
};

const FRAME_TAKEN = true;
const FRAME_FREE = false;

var frameMap: [TOTAL_NUMBER_OF_FRAMES]bool = undefined;

const std = @import("std");

pub fn initialize() void {
    mark_frames(0, KERNEL_BASE_FRAMES_COUNT);
}

pub fn allocate(needed_frames: usize) !void {
    if ((needed_frames < 1) or
        (needed_frames > (TOTAL_NUMBER_OF_FRAMES - KERNEL_BASE_FRAMES_COUNT)))
    {
        return PmmError.InvalidSize;
    }

    const start_frame = try get_start_frame(needed_frames);
    mark_frames(start_frame, needed_frames);
}

pub fn free(start_frame: usize, total_frames: usize) !void {
    // Kernel base is off limits.
    if ((start_frame < KERNEL_BASE_FRAMES_COUNT) or
        (start_frame + total_frames) > frameMap.len)
    {
        return PmmError.InvalidIndex;
    }

    const end_frame: usize = start_frame + total_frames;

    for (start_frame..end_frame) |frame| {
        frameMap[frame] = FRAME_FREE;
    }
}

fn get_start_frame(needed_frames: usize) !usize {
    var frame_count: usize = 0;
    var start_frame: usize = 0;
    var is_first: bool = true;

    for (0..TOTAL_NUMBER_OF_FRAMES) |frame| {
        if (frameMap[frame] == FRAME_TAKEN) {
            frame_count = 0;
            start_frame = 0;
            is_first = true;
            continue;
        }

        if (is_first) {
            is_first = false;
            start_frame = frame;
        }

        frame_count += 1;

        if (frame_count == needed_frames) {
            return start_frame;
        }
    }

    return PmmError.OutOfMemory;
}

fn mark_frames(start_frame: usize, total_frames: usize) void {
    const end_frame: usize = start_frame + total_frames;

    for (start_frame..end_frame) |frame| {
        frameMap[frame] = FRAME_TAKEN;
    }
}
