const std = @import("std");

pub const HeapError = error{
    OutOfMemory,
};

/// Minimum block size: must be large enough to hold header + footer + free list next pointer.
const MINIMUM_BLOCK_SIZE: usize = @sizeOf(BlockHeader) + @sizeOf(BlockFooter) + @sizeOf(usize);

/// Default alignment for all heap allocations.
const DEFAULT_ALIGNMENT: usize = 8;

const BlockHeader = struct {
    /// Total block size including header and footer.
    size: usize,
    /// Whether this block is free.
    free: bool,
};

const BlockFooter = struct {
    /// Total block size (must match the header's size).
    size: usize,
};

/// A free-list based heap allocator with block coalescing and splitting.
///
/// Memory layout of each block:
///   [BlockHeader | user data | BlockFooter]
///
/// Free blocks store a pointer to the next free block in the user data area.
/// The footer at the end of each block enables O(1) coalescing with the previous block.
pub const Heap = struct {
    start_address: usize,
    end_address: usize,
    free_list: ?*FreeBlock,

    const FreeBlock = struct {
        next: ?*FreeBlock,
    };

    /// Initializes the heap structure with a specific memory region.
    pub fn initialize(start_address: usize, size_in_bytes: usize) Heap {
        var heap = Heap{
            .start_address = start_address,
            .end_address = start_address + size_in_bytes,
            .free_list = null,
        };
        heap.initializeFreeList();
        return heap;
    }

    fn initializeFreeList(self: *Heap) void {
        // Create the initial free block covering the entire heap region.
        const header = @as(*BlockHeader, @ptrFromInt(self.start_address));
        header.size = self.end_address - self.start_address;
        header.free = true;

        const footer = getFooter(header);
        footer.size = header.size;

        // Initialize the free block's next pointer (stored in user data area).
        const free_block = @as(*FreeBlock, @ptrFromInt(self.start_address + @sizeOf(BlockHeader)));
        free_block.next = null;

        self.free_list = free_block;
    }

    /// Allocates a block of memory from the heap.
    pub fn allocate(self: *Heap, size_in_bytes: usize, alignment: usize) HeapError![*]u8 {
        const actual_alignment = @max(alignment, DEFAULT_ALIGNMENT);
        const aligned_size = alignForward(size_in_bytes, DEFAULT_ALIGNMENT);

        // Walk the free list to find a suitable block (first-fit).
        var prev: ?*FreeBlock = null;
        var current = self.free_list;
        while (current) |block| {
            const block_start = @intFromPtr(getHeaderFromFreeBlock(block));
            const header = getHeaderFromFreeBlock(block);

            // Calculate where the user data would need to start to satisfy alignment.
            const aligned_user_data = alignForward(block_start + @sizeOf(BlockHeader), actual_alignment);
            const header_offset = aligned_user_data - @sizeOf(BlockHeader);
            const alloc_block_size = @sizeOf(BlockHeader) + aligned_size + @sizeOf(BlockFooter);
            const consumed_from_block = (header_offset - block_start) + alloc_block_size;

            // Save the original block size before any modifications, since
            // writing the padding header or allocation header will overwrite it.
            const original_block_size = header.size;

            if (original_block_size >= consumed_from_block) {
                // Found a suitable block. Remove it from the free list.
                if (prev) |p| {
                    p.next = block.next;
                } else {
                    self.free_list = block.next;
                }

                // If there is space before the aligned header, create a padding free block.
                if (header_offset > block_start) {
                    const padding_size = header_offset - block_start;
                    if (padding_size >= MINIMUM_BLOCK_SIZE) {
                        const padding_header = @as(*BlockHeader, @ptrFromInt(block_start));
                        padding_header.size = padding_size;
                        padding_header.free = true;
                        const padding_footer = getFooter(padding_header);
                        padding_footer.size = padding_size;
                        self.insertIntoFreeList(padding_header);
                    }
                    // If padding is too small, it is wasted space (internal fragmentation).
                }

                // Set up the allocated block at the aligned position.
                const alloc_header = @as(*BlockHeader, @ptrFromInt(header_offset));
                alloc_header.size = alloc_block_size;
                alloc_header.free = false;
                const alloc_footer = getFooter(alloc_header);
                alloc_footer.size = alloc_block_size;

                // If there is space after the allocation, create a new free block.
                const remaining = original_block_size - consumed_from_block;
                if (remaining >= MINIMUM_BLOCK_SIZE) {
                    const new_free_addr = header_offset + alloc_block_size;
                    const new_header = @as(*BlockHeader, @ptrFromInt(new_free_addr));
                    new_header.size = remaining;
                    new_header.free = true;
                    const new_footer = getFooter(new_header);
                    new_footer.size = remaining;
                    self.insertIntoFreeList(new_header);
                }

                return @as([*]u8, @ptrFromInt(aligned_user_data));
            }

            prev = current;
            current = block.next;
        }

        return HeapError.OutOfMemory;
    }

    /// Frees a previously allocated block of memory.
    pub fn free(self: *Heap, bytes: []u8) void {
        if (bytes.len == 0) return;
        const user_ptr = bytes.ptr;
        const header = @as(*BlockHeader, @ptrFromInt(@intFromPtr(user_ptr) - @sizeOf(BlockHeader)));
        header.free = true;

        // Coalesce with the next block if it is free.
        const next_header_addr = @intFromPtr(header) + header.size;
        if (next_header_addr < self.end_address) {
            const next_header = @as(*BlockHeader, @ptrFromInt(next_header_addr));
            if (next_header.free) {
                // Remove the next block from the free list.
                self.removeFromFreeList(next_header);
                // Merge.
                header.size += next_header.size;
                const footer = getFooter(header);
                footer.size = header.size;
            }
        }

        // Coalesce with the previous block if it is free.
        if (@intFromPtr(header) > self.start_address) {
            const prev_footer = @as(*BlockFooter, @ptrFromInt(@intFromPtr(header) - @sizeOf(BlockFooter)));
            const prev_header_addr = @intFromPtr(header) - prev_footer.size;
            const prev_header = @as(*BlockHeader, @ptrFromInt(prev_header_addr));
            if (prev_header.free) {
                // Remove the previous block from the free list (its size is changing).
                self.removeFromFreeList(prev_header);
                // Merge.
                prev_header.size += header.size;
                const footer = getFooter(prev_header);
                footer.size = prev_header.size;
                // Re-insert with the new size.
                self.insertIntoFreeList(prev_header);
                return;
            }
        }

        // Insert the freed block into the free list.
        self.insertIntoFreeList(header);
    }

    /// Resizes a previously allocated block. Returns true if successful.
    pub fn resize(self: *Heap, bytes: []u8, new_size_in_bytes: usize) bool {
        if (bytes.len == 0) return false;
        const user_ptr = bytes.ptr;
        const header = @as(*BlockHeader, @ptrFromInt(@intFromPtr(user_ptr) - @sizeOf(BlockHeader)));

        const aligned_new_size = alignForward(new_size_in_bytes, DEFAULT_ALIGNMENT);
        const total_needed = @sizeOf(BlockHeader) + aligned_new_size + @sizeOf(BlockFooter);

        if (total_needed <= header.size) {
            // Shrinking: split off the excess if it is large enough.
            const remaining = header.size - total_needed;
            if (remaining >= MINIMUM_BLOCK_SIZE) {
                header.size = total_needed;
                var footer = getFooter(header);
                footer.size = total_needed;

                const new_free_addr = @intFromPtr(header) + total_needed;
                const new_header = @as(*BlockHeader, @ptrFromInt(new_free_addr));
                new_header.size = remaining;
                new_header.free = true;
                const new_footer = getFooter(new_header);
                new_footer.size = remaining;

                self.insertIntoFreeList(new_header);
            }
            return true;
        }

        // Growing: check if the next block is free and can be merged.
        const next_header_addr = @intFromPtr(header) + header.size;
        if (next_header_addr < self.end_address) {
            const next_header = @as(*BlockHeader, @ptrFromInt(next_header_addr));
            if (next_header.free) {
                const combined_size = header.size + next_header.size;
                if (combined_size >= total_needed) {
                    // Remove the next block from the free list.
                    self.removeFromFreeList(next_header);

                    // Merge.
                    header.size = combined_size;
                    var footer = getFooter(header);
                    footer.size = combined_size;

                    // Split off any excess.
                    const remaining = header.size - total_needed;
                    if (remaining >= MINIMUM_BLOCK_SIZE) {
                        header.size = total_needed;
                        footer = getFooter(header);
                        footer.size = total_needed;

                        const new_free_addr = @intFromPtr(header) + total_needed;
                        const new_header = @as(*BlockHeader, @ptrFromInt(new_free_addr));
                        new_header.size = remaining;
                        new_header.free = true;
                        const new_footer = getFooter(new_header);
                        new_footer.size = remaining;

                        self.insertIntoFreeList(new_header);
                    }
                    return true;
                }
            }
        }

        return false;
    }

    /// Returns a standard Zig Allocator interface for this heap.
    pub fn allocator(self: *Heap) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = allocateVtableEntry,
                .resize = resizeVtableEntry,
                .remap = remapVtableEntry,
                .free = freeVtableEntry,
            },
        };
    }

    fn allocateVtableEntry(context: *anyopaque, length: usize, pointer_alignment: std.mem.Alignment, _: usize) ?[*]u8 {
        const self: *Heap = @ptrCast(@alignCast(context));
        const alignment = @as(usize, 1) << @as(u6, @intCast(@intFromEnum(pointer_alignment)));
        return self.allocate(length, alignment) catch null;
    }

    fn resizeVtableEntry(context: *anyopaque, bytes: []u8, _: std.mem.Alignment, new_length: usize, _: usize) bool {
        const self: *Heap = @ptrCast(@alignCast(context));
        return self.resize(bytes, new_length);
    }

    fn remapVtableEntry(context: *anyopaque, bytes: []u8, _: std.mem.Alignment, new_length: usize, _: usize) ?[*]u8 {
        const self: *Heap = @ptrCast(@alignCast(context));
        if (self.resize(bytes, new_length)) {
            return bytes.ptr;
        }
        return null;
    }

    fn freeVtableEntry(context: *anyopaque, bytes: []u8, _: std.mem.Alignment, _: usize) void {
        const self: *Heap = @ptrCast(@alignCast(context));
        self.free(bytes);
    }

    // --- Helper functions ---

    fn getFooter(header: *BlockHeader) *BlockFooter {
        return @as(*BlockFooter, @ptrFromInt(@intFromPtr(header) + header.size - @sizeOf(BlockFooter)));
    }

    fn getHeaderFromFreeBlock(free_block: *FreeBlock) *BlockHeader {
        return @as(*BlockHeader, @ptrFromInt(@intFromPtr(free_block) - @sizeOf(BlockHeader)));
    }

    fn removeFromFreeList(self: *Heap, header: *BlockHeader) void {
        const free_block = @as(*FreeBlock, @ptrFromInt(@intFromPtr(header) + @sizeOf(BlockHeader)));
        var prev: ?*FreeBlock = null;
        var current = self.free_list;
        while (current) |block| {
            if (block == free_block) {
                if (prev) |p| {
                    p.next = block.next;
                } else {
                    self.free_list = block.next;
                }
                return;
            }
            prev = current;
            current = block.next;
        }
    }

    fn insertIntoFreeList(self: *Heap, header: *BlockHeader) void {
        const free_block = @as(*FreeBlock, @ptrFromInt(@intFromPtr(header) + @sizeOf(BlockHeader)));
        const block_addr = @intFromPtr(header);

        // Insert sorted by address to maintain order for coalescing.
        var prev: ?*FreeBlock = null;
        var current = self.free_list;
        while (current) |block| {
            const current_addr = @intFromPtr(getHeaderFromFreeBlock(block));
            if (block_addr < current_addr) {
                free_block.next = current;
                if (prev) |p| {
                    p.next = free_block;
                } else {
                    self.free_list = free_block;
                }
                return;
            }
            prev = current;
            current = block.next;
        }

        // Append to end.
        free_block.next = null;
        if (prev) |p| {
            p.next = free_block;
        } else {
            self.free_list = free_block;
        }
    }
};

fn alignForward(addr: usize, alignment: usize) usize {
    return (addr + alignment - 1) & ~(alignment - 1);
}
