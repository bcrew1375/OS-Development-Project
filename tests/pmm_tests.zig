const kernel = @import("kernel");
const std = @import("std");

pub const ErrSet = error{
    TestErr,
};

test "PMM allocation - InvalidSize" {
    const err = kernel.pmm.PmmError.InvalidSize;

    kernel.pmm.initialize();

    try std.testing.expectError(err, kernel.pmm.allocate(0));
    try std.testing.expectError(err, kernel.pmm.allocate(kernel.pmm.TOTAL_NUMBER_OF_FRAMES - kernel.pmm.KERNEL_BASE_FRAMES_COUNT + 1));
}

test "PMM allocation - OutOfMemory" {
    const err = kernel.pmm.PmmError.OutOfMemory;

    kernel.pmm.initialize();

    try kernel.pmm.allocate(kernel.pmm.TOTAL_NUMBER_OF_FRAMES - kernel.pmm.KERNEL_BASE_FRAMES_COUNT);
    try std.testing.expectError(err, kernel.pmm.allocate(1));
}

test "PMM allocation - InvalidIndex" {
    const err = kernel.pmm.PmmError.InvalidIndex;

    kernel.pmm.initialize();

    try std.testing.expectError(err, kernel.pmm.free(0, kernel.pmm.KERNEL_BASE_FRAMES_COUNT));
    try std.testing.expectError(err, kernel.pmm.free(kernel.pmm.TOTAL_NUMBER_OF_FRAMES, 1));
}
