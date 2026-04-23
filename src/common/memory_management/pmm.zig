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
var totalSystemFrames: usize = undefined;
var totalAvailableFrames: usize = undefined;

const FrameInfo = extern struct {
    used: bool = undefined,
    reserved: bool = undefined,
};

var frameMap: []FrameInfo = undefined;

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

    var max_address: u64 = 0;

    for (memoryMap.entries[0..memoryMap.length]) |region| {
        if (region.region_type != arch.MemoryMapEntryType.AVAILABLE) {
            continue;
        }

        if (region.address + region.size > max_address) {
            max_address = region.address + region.size;
        }
    }

    totalFrames = @truncate(try std.math.divFloor(u64, max_address, FRAME_SIZE));

    frameMap = @as([*]FrameInfo, @ptrCast(@alignCast(try arch.boot.allocate(totalFrames * @sizeOf(FrameInfo), FRAME_SIZE, arch.ReservedMapEntryType.PERSISTENT))))[0..totalFrames];

    for (memoryMap.entries[0..memoryMap.length]) |region| {
        const region_start_frame: usize = @truncate(try std.math.divCeil(u64, region.address, FRAME_SIZE));
        const region_end_frame: usize = @truncate(try std.math.divTrunc(u64, region.address + region.size, FRAME_SIZE));

        if (region_end_frame > totalFrames) {
            continue;
        }

        var used = true;
        var reserved = true;

        switch (region.region_type) {
            arch.MemoryMapEntryType.AVAILABLE => {
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
            frameMap[frame].used = used;
            frameMap[frame].reserved = reserved;
        }
    }

    //markFrames(kernelBaseStartFrame, kernelBaseEndFrame - kernelBaseStartFrame, arch.MemoryMapEntryType.RESERVED);

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

// pub fn allocate(needed_frames: usize) !usize {
//     if ((needed_frames < 1) or
//         (needed_frames > (totalAvailableFrames - getKernelBaseFrames())))
//     {
//         return PmmError.InvalidSize;
//     }

//     std.debug.print("Needed Frames: {d}\n", .{needed_frames});
//     std.debug.print("Total Frames: {d}\n", .{totalAvailableFrames});
//     std.debug.print("Kernel Frames: {d}\n", .{getKernelBaseFrames()});

//     const start_frame = try get_start_frame(needed_frames);
//     const end_frame: usize = start_frame + needed_frames;

//     for (start_frame..end_frame) |frame| {
//         frameMap[frame].availability = FrameAvailability.Used;
//     }

//     return start_frame * FRAME_SIZE;
// }

// pub fn reserve(start_frame: usize, total_frames: usize) !void {
//     if (start_frame + total_frames > totalAvailableFrames) {
//         return PmmError.InvalidIndex;
//     }

//     for (start_frame..start_frame + total_frames) |frame| {
//         frameMap[frame].reserved = true;
//     }
// }

// pub fn free(start_frame: usize, total_frames: usize) !void {
//     if (start_frame > totalAvailableFrames) {
//         return PmmError.InvalidIndex;
//     }

//     const end_frame: usize = start_frame + total_frames;

//     for (start_frame..end_frame) |frame| {
//         frameMap[frame].availability = FrameAvailability.Free;
//     }
// }

// fn get_start_frame(needed_frames: usize) !usize {
//     var frame_count: usize = 0;
//     var start_frame: usize = 0;
//     var is_first: bool = true;

//     for (0..totalAvailableFrames) |frame| {
//         if (frameMap.isSet(frame)) {
//             frame_count = 0;
//             start_frame = 0;
//             is_first = true;
//             continue;
//         }

//         if (is_first) {
//             is_first = false;
//             start_frame = frame;
//         }

//         frame_count += 1;

//         if (frame_count == needed_frames) {
//             return start_frame;
//         }
//     }

//     return PmmError.OutOfMemory;
// }

fn markFrames(start_frame: usize, total_frames: usize, region_type: arch.MemoryMapEntryType) void {
    const end_frame: usize = start_frame + total_frames;

    for (start_frame..end_frame) |frame| {
        switch (region_type) {
            arch.MemoryMapEntryType.AVAILABLE => {
                frameMap[frame].used = false;
            },
            else => {
                frameMap[frame].reserved = true;
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
