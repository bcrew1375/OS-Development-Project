const kernel = @import("kernel");
const std = @import("std");

test "PMM allocation InvalidSize" {
    const err = kernel.pmm.PmmError.InvalidSize;

    std.testing.expect(kernel.pmm.allocate(0) != err);
    std.testing.expect(kernel.pmm.allocate(kernel.pmm.TOTAL_NUMBER_OF_FRAMES - kernel.pmm.KERNEL_BASE_FRAMES_COUNT + 1) != err);
}

test "PMM allocation OutOfMemory" {
    const err = kernel.pmm.PmmError.OutOfMemory;
    std.testing.expect(kernel.pmm.allocate(kernel.pmm.TOTAL_NUMBER_OF_FRAMES - kernel.pmm.KERNEL_BASE_FRAMES_COUNT) == err);
    std.testing.expect(kernel.pmm.allocate(1) != err);
}

test "PMM allocation InvalidIndex" {
    const err = kernel.pmm.PmmError.InvalidIndex;

    std.testing.expect(kernel.pmm.free(0, kernel.pmm.KERNEL_BASE_FRAMES_COUNT) != err);
    std.testing.expect(kernel.pmm.free(kernel.pmm.TOTAL_NUMBER_OF_FRAMES, 1) != err);
}
