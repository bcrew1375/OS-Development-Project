const arch = @import("arch");

pub const FRAME_SIZE: usize = 4096;
// Max 64 GBs for now.
pub const MAX_FRAMES: usize = 2097152;

// Reserve the first 4 MBs for the kernel and hardware.
extern const _kernel_start: anyopaque;
extern const _kernel_end: anyopaque;

pub const PmmError = error{
    OutOfMemory,
    InvalidSize,
    InvalidIndex,
};

var kernelBaseStartFrame: usize = undefined;
var kernelBaseEndFrame: usize = undefined;
var totalAvailableRAM: usize = 0;

const std = @import("std");
const FrameBitmap = std.StaticBitSet(MAX_FRAMES);

var frameMap: FrameBitmap linksection(".bss") = FrameBitmap.initEmpty();

pub fn initialize() !void {
    kernelBaseStartFrame = @intFromPtr(&_kernel_start) / FRAME_SIZE;
    kernelBaseEndFrame = (@intFromPtr(&_kernel_end) + (FRAME_SIZE - 1)) / FRAME_SIZE;

    const memoryMap: *arch.MemoryMap = arch.mmu.getMemoryMap();

    for (0..memoryMap.length) |entry| {
        const start_frame: usize = @truncate(try std.math.divCeil(u64, memoryMap.entries[entry].address, FRAME_SIZE));
        const total_frames: usize = @truncate(try std.math.divTrunc(u64, memoryMap.entries[entry].length, FRAME_SIZE));

        switch (memoryMap.entries[entry].available) {
            true => {
                try free(start_frame, total_frames);
                totalAvailableRAM += @truncate((total_frames * FRAME_SIZE));
            },
            else => mark_frames(start_frame, total_frames),
        }
    }

    mark_frames(kernelBaseStartFrame, kernelBaseEndFrame - kernelBaseEndFrame);

    // Also reserve the first 1MB for BIOS/Real Mode structures usually found on x86
    //mark_frames(0, 0x100000 / FRAME_SIZE);
}

pub fn allocate(needed_frames: usize) !usize {
    if ((needed_frames < 1) or
        (needed_frames > totalAvailableRAM))
    {
        return PmmError.InvalidSize;
    }

    const start_frame = try get_start_frame(needed_frames);
    mark_frames(start_frame, needed_frames);

    return start_frame * FRAME_SIZE;
}

pub fn reserve(start_frame: usize, total_frames: usize) !void {
    if (start_frame + total_frames > totalAvailableRAM) {
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

    for (0..totalAvailableRAM) |frame| {
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

pub fn getTotalRAM() usize {
    return totalAvailableRAM;
}
