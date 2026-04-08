// Assume 128 MBs of physical RAM for now.
// 128 MBs / 4 KB frame size = 32 KBs.
pub const TOTAL_NUMBER_OF_FRAMES: usize = 32768;
pub const FRAME_SIZE: usize = 4096;

// Reserve the first 4 MBs for the kernel and hardware.
extern const _kernel_start: anyopaque;
extern const _kernel_end: anyopaque;

pub const PmmError = error{
    OutOfMemory,
    InvalidSize,
    InvalidIndex,
};

const std = @import("std");
const FrameBitmap = std.StaticBitSet(TOTAL_NUMBER_OF_FRAMES);
var frameMap: FrameBitmap linksection(".bss") = FrameBitmap.initEmpty();

pub fn initialize() void {
    const start_frame = @intFromPtr(&_kernel_start) / FRAME_SIZE;
    const end_frame = (@intFromPtr(&_kernel_end) + (FRAME_SIZE - 1)) / FRAME_SIZE;

    mark_frames(start_frame, end_frame - start_frame);

    // Also reserve the first 1MB for BIOS/Real Mode structures usually found on x86
    mark_frames(0, 0x100000 / FRAME_SIZE);
}

pub fn allocate(needed_frames: usize) !usize {
    if ((needed_frames < 1) or
        (needed_frames > TOTAL_NUMBER_OF_FRAMES))
    {
        return PmmError.InvalidSize;
    }

    const start_frame = try get_start_frame(needed_frames);
    mark_frames(start_frame, needed_frames);

    return start_frame * FRAME_SIZE;
}

pub fn reserve(start_frame: usize, total_frames: usize) !void {
    if (start_frame + total_frames > TOTAL_NUMBER_OF_FRAMES) {
        return PmmError.InvalidIndex;
    }

    for (start_frame..start_frame + total_frames) |frame| {
        frameMap.set(frame);
    }
}

pub fn free(start_frame: usize, total_frames: usize) !void {
    // Kernel base is off limits.
    // if ((start_frame < KERNEL_BASE_FRAMES_COUNT) or
    //     (start_frame + total_frames) > TOTAL_NUMBER_OF_FRAMES)
    // {
    //     return PmmError.InvalidIndex;
    // }

    // const end_frame: usize = start_frame + total_frames;

    // for (start_frame..end_frame) |frame| {
    //     frameMap.unset(frame);
    // }
    _ = start_frame;
    _ = total_frames;
}

fn get_start_frame(needed_frames: usize) !usize {
    var frame_count: usize = 0;
    var start_frame: usize = 0;
    var is_first: bool = true;

    for (0..TOTAL_NUMBER_OF_FRAMES) |frame| {
        if (frameMap.isSet(frame)) {
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
        frameMap.set(frame);
    }
}
