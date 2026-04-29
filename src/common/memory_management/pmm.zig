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
    ReservedFree,
};

var kernelBaseStartFrame: usize = 0;
var kernelBaseEndFrame: usize = 0;

var totalFrames: usize = 0;
var totalSystemFrames: usize = 0;
var totalAvailableFrames: usize = 0;
var currentAvailableFrames: usize = 0;

const FrameInfo = extern struct {
    used: bool = undefined,
    reserved: bool = undefined,
};

var frameMap: []allowzero FrameInfo = undefined;

extern const _kernel_start: usize;
extern const _kernel_end: usize;

pub fn initialize() !void {
    if (builtin.is_test) {
        kernelBaseStartFrame = _kernel_start / FRAME_SIZE;
        kernelBaseEndFrame = _kernel_end / FRAME_SIZE;
    } else {
        kernelBaseStartFrame = @intFromPtr(&_kernel_start) / FRAME_SIZE;
        kernelBaseEndFrame = (@intFromPtr(&_kernel_end) + (FRAME_SIZE - 1)) / FRAME_SIZE;
    }

    totalFrames = 0;
    totalAvailableFrames = 0;
    currentAvailableFrames = 0;
    totalSystemFrames = 0;

    const memory_map = arch.mmu.getMemoryMap();

    totalFrames = @truncate(try std.math.divFloor(u64, arch.mmu.getMaxAvailableAddress(), FRAME_SIZE));

    const frameMapPtr: *allowzero anyopaque = try arch.early_allocator.allocate(totalFrames * @sizeOf(FrameInfo), FRAME_SIZE, arch.ReservedMapRegionType.PERSISTENT);
    frameMap = @as([*]allowzero FrameInfo, @ptrCast(@alignCast(frameMapPtr)))[0..totalFrames];

    for (memory_map.entries[0..memory_map.length]) |region| {
        const region_start_frame: usize = @truncate(try std.math.divCeil(u64, region.address, FRAME_SIZE));
        const region_end_frame: usize = @truncate(try std.math.divTrunc(u64, region.address + region.size, FRAME_SIZE));

        var used = true;
        var reserved = true;

        switch (region.region_type) {
            arch.MemoryMapRegionType.AVAILABLE => {
                used = false;
                reserved = false;

                totalAvailableFrames += region_end_frame - region_start_frame;
            },
            else => {
                used = true;
                reserved = true;
            },
        }

        for (region_start_frame..region_end_frame) |frame| {
            if (frame >= totalFrames) {
                break;
            }

            frameMap[frame].used = used;
            frameMap[frame].reserved = reserved;
        }
    }

    currentAvailableFrames = totalAvailableFrames;

    const reservedMap = arch.early_allocator.getReservedMap();

    for (reservedMap.entries[0..reservedMap.length]) |region| {
        const region_start_frame: usize = @truncate(try std.math.divFloor(u64, region.address, FRAME_SIZE));
        const region_total_frames: usize = @truncate((try std.math.divCeil(u64, region.address +| region.size, FRAME_SIZE)) - region_start_frame);

        try reserve(region_start_frame, region_total_frames);
    }

    // markFrames(kernelBaseStartFrame, kernelBaseEndFrame - kernelBaseStartFrame, arch.MemoryMapEntryType.RESERVED);

    // Also reserve the first 1MB for BIOS/Real Mode structures usually found on x86
    //mark_frames(0, 0x100000 / FRAME_SIZE);
}

// pub fn initializeFrameRegion(index: usize, address: u64, size: u64, region_type: arch.MemoryMapEntryType) !void {
//     const region_start_frame: usize = @truncate(try std.math.divCeil(u64, address, FRAME_SIZE));
//     var region_total_frames: usize = @truncate(try std.math.divTrunc(u64, size, FRAME_SIZE));

//     if (region_total_frames == 0) {
//         region_total_frames = 1;
//     }

//     if (region_type == arch.MemoryMapEntryType.AVAILABLE) {
//         totalAvailableFrames += region_total_frames;
//     } else {
//         memoryRegions[index].reserved = true;
//     }

//     totalFrames += region_total_frames;

//     memoryRegions[index].base_address = region_start_frame * FRAME_SIZE;
//     memoryRegions[index].frames = @as([*]FrameInfo, @ptrCast(@alignCast(try arch.boot.allocate(region_total_frames * @sizeOf(FrameInfo), FRAME_SIZE, arch.ReservedMapEntryType.PERSISTENT))));

//     //markFrames(region_start_frame, region_total_frames, region_type);
// }

pub fn allocate(needed_frames: usize) !usize {
    if ((needed_frames < 1) or
        (needed_frames > totalAvailableFrames))
    {
        return PmmError.InvalidSize;
    }

    if (needed_frames > currentAvailableFrames) {
        return PmmError.OutOfMemory;
    }

    const start_frame = try get_start_frame(needed_frames);
    const end_frame: usize = start_frame + needed_frames;

    for (start_frame..end_frame) |frame| {
        frameMap[frame].used = true;
    }

    currentAvailableFrames -= needed_frames;

    return start_frame * FRAME_SIZE;
}

pub fn reserve(start_frame: usize, total_frames: usize) !void {
    for (start_frame..start_frame + total_frames) |frame| {
        frameMap[frame].used = true;
        frameMap[frame].reserved = true;
    }

    totalSystemFrames +|= total_frames;
    currentAvailableFrames -|= total_frames;
}

pub fn free(start_frame: usize, total_frames: usize) !void {
    const end_frame: usize = start_frame +| total_frames;

    if (end_frame > totalFrames) {
        return PmmError.InvalidIndex;
    }

    if (total_frames > totalAvailableFrames) {
        return PmmError.InvalidSize;
    }

    for (start_frame..end_frame) |frame| {
        if (frameMap[frame].reserved == true) {
            return PmmError.ReservedFree;
        }

        frameMap[frame].used = false;
    }

    currentAvailableFrames += total_frames;
}

fn get_start_frame(needed_frames: usize) !usize {
    var frame_count: usize = 0;
    var start_frame: usize = 0;
    var is_first: bool = true;

    for (0..totalFrames) |frame| {
        if (frameMap[frame].used == true) {
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

fn markFrames(start_frame: usize, total_frames: usize, region_type: arch.MemoryMapRegionType) void {
    const end_frame: usize = start_frame + total_frames;

    for (start_frame..end_frame) |frame| {
        switch (region_type) {
            arch.MemoryMapRegionType.AVAILABLE => {
                frameMap[frame].used = false;
            },
            else => {
                frameMap[frame].reserved = true;
            },
        }
    }
}

pub fn getTotalFrames() usize {
    return totalFrames;
}

pub fn getTotalAvailableFrames() usize {
    return totalAvailableFrames;
}

pub fn getCurrentAvailableFrames() usize {
    return currentAvailableFrames;
}

pub fn getTotalAvailableRAM() u64 {
    return totalAvailableFrames * FRAME_SIZE;
}

pub fn getTotalSystemFrames() usize {
    return totalSystemFrames;
}

pub fn getTotalSystemReservedRAM() u64 {
    return totalSystemFrames * FRAME_SIZE;
}
