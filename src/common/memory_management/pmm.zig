const arch = @import("arch");

const builtin = @import("builtin");
const std = @import("std");

pub const FRAME_SIZE: usize = 4096;
// Max 64 GBs for now.
pub const MAX_FRAMES: usize = 2097152;

pub const PmmError = error{
    OutOfMemory,
    InvalidSize,
    InvalidIndex,
};

var kernelBaseStartFrame: usize = undefined;
var kernelBaseEndFrame: usize = undefined;
var totalFrames: usize = undefined;
var totalAvailableFrames: usize = undefined;

const FrameAvailability = enum(u8) {
    Free,
    Used,
    Reserved,
};

const FrameInfo = extern struct {
    availability: FrameAvailability,
};

const MemoryRegion = extern struct {
    base_address: u64,
    frames: []FrameInfo,
};

var frameMap: *[]MemoryRegion = undefined;

extern const _kernel_start: anyopaque;
extern const _kernel_end: anyopaque;

pub fn initialize() !void {
    if (builtin.is_test) {
        kernelBaseStartFrame = _kernel_start / FRAME_SIZE;
        kernelBaseEndFrame = _kernel_end / FRAME_SIZE;
    } else {
        kernelBaseStartFrame = @intFromPtr(&_kernel_start) / FRAME_SIZE;
        kernelBaseEndFrame = (@intFromPtr(&_kernel_end) + (FRAME_SIZE - 1)) / FRAME_SIZE;
    }

    const memoryMap = arch.mmu.getMemoryMap();

    frameMap = @as([*]FrameInfo, @ptrCast(arch.boot.allocate(totalFrames * @sizeOf(FrameInfo), FRAME_SIZE, arch.ReservedMapEntryType.PERSISTENT)))[0..totalFrames];

    for (memoryMap.entries[0..memoryMap.length]) |entry| {
        try initializeFrameRegion(entry.address, entry.size, entry.region_type);
    }

    markFrames(kernelBaseStartFrame, kernelBaseEndFrame - kernelBaseStartFrame, arch.MemoryMapEntryType.RESERVED);

    // Also reserve the first 1MB for BIOS/Real Mode structures usually found on x86
    //mark_frames(0, 0x100000 / FRAME_SIZE);
}

pub fn initializeFrameRegion(address: u64, size: u64, region_type: arch.MemoryMapEntryType) !*MemoryRegion {
    var region_start_frame: usize = undefined;
    var region_total_frames: usize = undefined;

    if (region_type == arch.MemoryMapEntryType.AVAILABLE) {
        region_start_frame = @truncate(try std.math.divCeil(u64, address, FRAME_SIZE));
        region_total_frames = @truncate(try std.math.divFloor(u64, size, FRAME_SIZE));

        totalAvailableFrames += region_total_frames;
    }

    markFrames(region_start_frame, region_total_frames, region_type);
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
    const end_frame: usize = start_frame + needed_frames;

    for (start_frame..end_frame) |frame| {
        frameMap[frame].availability = FrameAvailability.Used;
    }

    return start_frame * FRAME_SIZE;
}

pub fn reserve(start_frame: usize, total_frames: usize) !void {
    if (start_frame + total_frames > totalAvailableFrames) {
        return PmmError.InvalidIndex;
    }

    for (start_frame..start_frame + total_frames) |frame| {
        frameMap[frame].reserved = true;
    }
}

pub fn free(start_frame: usize, total_frames: usize) !void {
    if (start_frame > totalAvailableFrames) {
        return PmmError.InvalidIndex;
    }

    const end_frame: usize = start_frame + total_frames;

    for (start_frame..end_frame) |frame| {
        frameMap[frame].availability = FrameAvailability.Free;
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

fn markFrames(start_frame: usize, total_frames: usize, region_type: arch.MemoryMapEntryType) void {
    const end_frame: usize = start_frame + total_frames;

    for (start_frame..end_frame) |frame| {
        switch (region_type) {
            arch.MemoryMapEntryType.AVAILABLE => {
                frameMap[frame].availability = FrameAvailability.Free;
            },
            else => {
                frameMap[frame].availability = FrameAvailability.Reserved;
            },
        }
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
