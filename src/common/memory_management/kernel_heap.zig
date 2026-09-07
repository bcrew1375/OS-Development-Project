//! Global kernel heap facade backed by the common boundary-tag allocator.

const arch = @import("arch");
const heap = @import("heap.zig");
const std = @import("std");

var kernelHeap: heap.Heap = undefined;
/// Global Zig allocator interface for kernel dynamic allocations.
pub var kernelAllocator: std.mem.Allocator = undefined;

var allocatedBlockBytes: u64 = 0;

/// Initializes the kernel heap from architecture-provided heap bounds.
pub fn initialize() !void {
    const heapStartAddress = arch.mmu.getKernelHeapVirtualAddress();
    const heapSize = arch.mmu.getKernelHeapSize();

    kernelHeap = heap.Heap.initialize(@intCast(heapStartAddress), @intCast(heapSize));
    kernelAllocator = kernelHeap.allocator();
}

/// Returns the global kernel allocator.
pub fn allocator() std.mem.Allocator {
    return kernelAllocator;
}

/// Allocates `size` bytes from the kernel heap.
pub fn kmalloc(size: usize) !*anyopaque {
    const pointer = try kernelHeap.allocate(size, 8);
    const header = heap.getBlockHeaderFromAllocation(pointer[0..size]);
    allocatedBlockBytes += header.size;
    return @ptrCast(pointer);
}

/// Frees a previous `kmalloc` allocation represented by `bytes`.
pub fn kfree(bytes: []u8) void {
    if (bytes.len == 0) return;

    const header = heap.getBlockHeaderFromAllocation(bytes);
    allocatedBlockBytes -= header.size;
    kernelHeap.free(bytes);
}

/// Returns total heap block bytes currently allocated, including allocator metadata.
pub fn getAllocatedBlockBytes() u64 {
    return allocatedBlockBytes;
}

/// Compatibility alias for `getAllocatedBlockBytes`.
pub fn getDynamicAllocationSize() u64 {
    return getAllocatedBlockBytes();
}
