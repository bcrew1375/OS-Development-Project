const std = @import("std");
const arch = @import("architecture/architecture.zig");
const kernel = @import("kernel_common.zig");

// The PMM expects these symbols to be defined by the linker.
// For testing purposes, we export them here.
export const _kernel_start: usize = 0;
export const _kernel_end: usize = 1024 * 1024;

fn testSetup() void {
    arch.early_allocator.initialize() catch {
        std.debug.print("Test initialization failed.", .{});
    };
}

test "Physical Memory Manager: Initialization" {
    testSetup();
    try kernel.pmm.initialize();

    const total_available_frames = kernel.pmm.getTotalAvailableFrames();
    const available_ram = kernel.pmm.getTotalAvailableRAM();

    try std.testing.expect(total_available_frames > 0);
    try std.testing.expect(available_ram > 0);
    try std.testing.expect(kernel.pmm.getTotalAvailableFrames() <= kernel.pmm.getTotalFrames());
    try std.testing.expect(kernel.pmm.getCurrentAvailableFrames() <= kernel.pmm.getTotalAvailableFrames());
}

test "Physical Memory Manager: Allocate and Free Single Frame" {
    try kernel.pmm.initialize();
    const initial_available = kernel.pmm.getCurrentAvailableFrames();

    const address = try kernel.pmm.allocate(1);

    // Ensure address is frame-aligned
    try std.testing.expect(address % kernel.pmm.FRAME_SIZE == 0);
    try std.testing.expectEqual(initial_available - 1, kernel.pmm.getCurrentAvailableFrames());

    // Free the frame
    try kernel.pmm.free(address / kernel.pmm.FRAME_SIZE, 1);
    try std.testing.expectEqual(initial_available, kernel.pmm.getCurrentAvailableFrames());
}

test "Physical Memory Manager: Contiguous Allocation" {
    try kernel.pmm.initialize();
    const requested_frames = 16;
    const initial_available = kernel.pmm.getCurrentAvailableFrames();

    const address = try kernel.pmm.allocate(requested_frames);
    try std.testing.expectEqual(initial_available - requested_frames, kernel.pmm.getCurrentAvailableFrames());

    // Verify we can free the block
    try kernel.pmm.free(address / kernel.pmm.FRAME_SIZE, requested_frames);
    try std.testing.expectEqual(initial_available, kernel.pmm.getCurrentAvailableFrames());
}

test "Physical Memory Manager: Out of Memory" {
    try kernel.pmm.initialize();
    const available = kernel.pmm.getCurrentAvailableFrames();

    // Attempting to allocate more than available should return InvalidSize or OutOfMemory
    const oversized_request = kernel.pmm.allocate(available + 1);
    try std.testing.expectError(kernel.pmm.PmmError.InvalidSize, oversized_request);

    // Allocate everything
    const address = try kernel.pmm.allocate(available);
    try std.testing.expectEqual(0, kernel.pmm.getCurrentAvailableFrames());

    // Next allocation should fail
    const failed_request = kernel.pmm.allocate(1);
    try std.testing.expectError(kernel.pmm.PmmError.OutOfMemory, failed_request);

    // Cleanup
    try kernel.pmm.free(address / kernel.pmm.FRAME_SIZE, available);
}

test "Physical Memory Manager: Zero Size Allocation" {
    try kernel.pmm.initialize();
    const result = kernel.pmm.allocate(0);
    try std.testing.expectError(kernel.pmm.PmmError.InvalidSize, result);
}
