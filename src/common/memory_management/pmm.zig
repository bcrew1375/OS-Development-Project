const arch = @import("arch");

const builtin = @import("builtin");
const std = @import("std");

pub const FRAME_SIZE: usize = 4096;
// Max 64 GBs for now.
pub const MAX_FRAMES: usize = 2097152;

extern const _kernel_start: usize;
extern const _kernel_end: usize;

pub const PmmError = error{
    OutOfMemory,
    InvalidSize,
    InvalidIndex,
};

var kernelBaseStartFrame: usize = undefined;
var kernelBaseEndFrame: usize = undefined;
var totalAvailableFrames: usize = 0;

FrameMap = packed struct {
    free: bool,
    used: bool,
    reserved: bool,
};

const FrameBitmap = std.StaticBitSet(MAX_FRAMES);
const memoryMap: *arch.MemoryMap = undefined;

var frameMap: FrameBitmap linksection(".bss") = FrameBitmap.initEmpty();

pub fn initialize() !void {
    if (builtin.is_test) {
        kernelBaseStartFrame = _kernel_start / FRAME_SIZE;
        kernelBaseEndFrame = _kernel_end / FRAME_SIZE;
    } else {
        kernelBaseStartFrame = @intFromPtr(&_kernel_start) / FRAME_SIZE;
        kernelBaseEndFrame = (@intFromPtr(&_kernel_end) + (FRAME_SIZE - 1)) / FRAME_SIZE;
    }

    memoryMap = arch.mmu.getMemoryMap();

    for (0..memoryMap.length) |entry| {
        const region_start_frame: usize = @truncate(try std.math.divCeil(u64, memoryMap.entries[entry].address, FRAME_SIZE));
        const region_total_frames: usize = @truncate(try std.math.divTrunc(u64, memoryMap.entries[entry].length, FRAME_SIZE));

        switch (memoryMap.entries[entry].available) {
            true => {
                try free(region_start_frame, region_total_frames);
                totalAvailableFrames += region_total_frames;
            },
            else => mark_frames(region_start_frame, region_total_frames),
        }
    }

    mark_frames(kernelBaseStartFrame, kernelBaseEndFrame - kernelBaseStartFrame);

    // Also reserve the first 1MB for BIOS/Real Mode structures usually found on x86
    //mark_frames(0, 0x100000 / FRAME_SIZE);
}

pub fn allocate(needed_frames: usize) !usize {
    if ((needed_frames < 1) or
        (needed_frames > (totalAvailableFrames - getKernelBaseFrames())))
    {
        return PmmError.InvalidSize;
    }

    std.debug.print("Needed Frames: {d}\n", .{needed_frames});
    std.debug.print("Total Frames: {d}\n", .{totalAvailableFrames});
    std.debug.print("Kernel Frames: {d}\n", .{getKernelBaseFrames()});

    const start_frame = try get_start_frame(needed_frames);
    mark_frames(start_frame, needed_frames);

    return start_frame * FRAME_SIZE;
}

pub fn reserve(start_frame: usize, total_frames: usize) !void {
    if (start_frame + total_frames > totalAvailableFrames) {
        return PmmError.InvalidIndex;
    }

    for (start_frame..start_frame + total_frames) |frame| {
        frameMap.set(frame);
    }
}

pub fn free(frame: usize) !void {
        return PmmError.InvalidIndex;
    }

    const end_frame: usize = start_frame + total_frames;

    for (start_frame..end_frame) |frame| {
        frameMap.unset(frame);
    }
}

fn get_start_frame(needed_frames: usize) !usize {
    var frame_count: usize = 0;
    var start_frame: usize = 0;
    var is_first: bool = true;

    for (0..totalAvailableFrames) |frame| {
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

pub fn getTotalFrames() usize {
    return totalAvailableFrames;
}

pub fn getTotalAvailableRAM() u64 {
    return totalAvailableFrames * FRAME_SIZE;
}

pub fn getKernelBaseFrames() usize {
    return kernelBaseEndFrame - kernelBaseStartFrame;
}
