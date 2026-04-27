const kernel = @import("kernel_common");
const std = @import("std");

const PmmTestError = error{
    InvalidMemoryMap,
};

test "PMM allocation - InvalidSize" {
    const err = kernel.pmm.PmmError.InvalidSize;

    try kernel.pmm.initialize();

    const total_frames = kernel.pmm.getTotalAvailableFrames();

    if (total_frames == 0) {
        return PmmTestError.InvalidMemoryMap;
    }

    try std.testing.expectError(err, kernel.pmm.allocate(0));
    try std.testing.expectError(err, kernel.pmm.allocate(total_frames + 1));
}

test "PMM allocation - OutOfMemory" {
    const err = kernel.pmm.PmmError.OutOfMemory;

    try kernel.pmm.initialize();

    const total_frames = kernel.pmm.getTotalFrames();

    if (total_frames == 0) {
        return PmmTestError.InvalidMemoryMap;
    }

    _ = try kernel.pmm.allocate(kernel.pmm.getTotalAvailableFrames());
    try std.testing.expectError(err, kernel.pmm.allocate(1));
}

test "PMM allocation - InvalidIndex" {
    const err = kernel.pmm.PmmError.InvalidIndex;

    try kernel.pmm.initialize();

    const total_frames = kernel.pmm.getTotalAvailableFrames();

    if (total_frames == 0) {
        return PmmTestError.InvalidMemoryMap;
    }

    try std.testing.expectError(err, kernel.pmm.free(kernel.pmm.getTotalAvailableFrames(), 1));
}
