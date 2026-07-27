const arch = @import("arch");
const heap = @import("heap.zig");
const std = @import("std");

var kernelHeap: heap.Heap = undefined;
pub var kernelAllocator: std.mem.Allocator = undefined;

var allocatedBlockBytes: u64 = 0;

pub fn initialize() !void {
    const heapStartAddress = arch.mmu.getKernelHeapVirtualAddress();
    const heapSize = arch.mmu.getKernelHeapSize();

    kernelHeap = heap.Heap.initialize(@intCast(heapStartAddress), @intCast(heapSize));
    kernelAllocator = kernelHeap.allocator();
}

pub fn allocator() std.mem.Allocator {
    return kernelAllocator;
}

pub fn kmalloc(size: usize) !*anyopaque {
    const pointer = try kernelHeap.allocate(size, 8);
    const header = heap.getBlockHeaderFromAllocation(pointer[0..size]);
    allocatedBlockBytes += header.size;
    return @ptrCast(pointer);
}

pub fn kfree(bytes: []u8) void {
    if (bytes.len == 0) return;

    const header = heap.getBlockHeaderFromAllocation(bytes);
    allocatedBlockBytes -= header.size;
    kernelHeap.free(bytes);
}

pub fn getAllocatedBlockBytes() u64 {
    return allocatedBlockBytes;
}

pub fn getDynamicAllocationSize() u64 {
    return getAllocatedBlockBytes();
}
