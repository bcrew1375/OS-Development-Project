const arch = @import("arch");
const heap = @import("heap.zig");
const pmm = @import("pmm.zig");
const std = @import("std");

var kernelHeap: heap.Heap = undefined;
pub var kernelAllocator: std.mem.Allocator = undefined;

var dynamicAllocationSize: u64 = 0;

pub fn initialize() !void {
    const heapStartAddress = arch.mmu.getKernelHeapVirtualAddress();
    const heapSize = arch.mmu.getKernelHeapSize();

    kernelHeap = heap.Heap.initialize(@intCast(heapStartAddress), @intCast(heapSize));
    kernelAllocator = kernelHeap.allocator();
}

pub fn kmalloc(size: usize) !*anyopaque {
    const pointer = try kernelHeap.allocate(size, 8);
    dynamicAllocationSize += size;
    return @ptrCast(pointer);
}

pub fn kfree(bytes: []u8) void {
    if (bytes.len == 0) return;

    const userPointer = bytes.ptr;
    const header = @as(*heap.BlockHeader, @ptrFromInt(@intFromPtr(userPointer) - @sizeOf(heap.BlockHeader)));

    // Record the block boundaries before freeing, since coalescing may change them.
    const blockStartAddress = @intFromPtr(header);
    const blockOriginalSize = header.size;
    const blockEndAddress = blockStartAddress + blockOriginalSize;

    // Return the block to the heap's free list (coalesces adjacent free blocks).
    kernelHeap.free(bytes);

    // After free(), the original block range is guaranteed to be free
    // (possibly merged into a larger free block). Release physical pages
    // for any complete 4KB pages entirely within the original range.
    const pageSize: usize = @intCast(arch.mmu.getPageSize());

    // Round up to the next page boundary from the start, and round down
    // from the end, to only touch pages fully contained in the freed range.
    const firstPageStart = (blockStartAddress + pageSize - 1) & ~(pageSize - 1);
    const lastPageStart = blockEndAddress & ~(pageSize - 1);

    var pageVirtualAddress = firstPageStart;
    while (pageVirtualAddress < lastPageStart) : (pageVirtualAddress += pageSize) {
        if (arch.mmu.getPhysicalAddress(pageVirtualAddress)) |physicalAddress| {
            const physicalFrame = physicalAddress / pageSize;
            arch.mmu.unmapPage(pageVirtualAddress);
            pmm.free(physicalFrame, 1) catch {};
        }
    }

    dynamicAllocationSize -= blockOriginalSize;
}

pub fn getDynamicAllocationSize() u64 {
    return dynamicAllocationSize;
}
