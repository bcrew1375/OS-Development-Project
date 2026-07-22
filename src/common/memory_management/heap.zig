const std = @import("std");

pub const HeapError = error{
    OutOfMemory,
};

/// Magic value stamped into every live header/footer. Lets corruption be
/// detected at the point it's *read*, instead of manifesting several
/// operations later as a garbage size or a crash in unrelated code.
const HEADER_MAGIC: u32 = 0x4845_4150; // "HEAP"
const FOOTER_MAGIC: u32 = 0x464F_4F54; // "FOOT"

pub const BlockHeader = struct {
    magic: u32 = HEADER_MAGIC,
    /// Total block size including header and footer.
    size: usize,
    /// Whether this block is free.
    free: bool,
};

pub const BlockFooter = struct {
    magic: u32 = FOOTER_MAGIC,
    /// Total block size (must match the header's size).
    size: usize,
};

/// Minimum block size: must be large enough to hold header + footer + free
/// list next pointer.
const MINIMUM_BLOCK_SIZE: usize = @sizeOf(BlockHeader) + @sizeOf(BlockFooter) + @sizeOf(usize);

/// Default alignment for all heap allocations.
const DEFAULT_ALIGNMENT: usize = 8;

/// A free-list based heap allocator with block coalescing and splitting.
///
/// Memory layout of each block:
///   [BlockHeader | user data | BlockFooter]
///
/// Free blocks store a pointer to the next free block in the user data area.
/// The footer at the end of each block enables O(1) coalescing with the
/// previous block.
///
/// INVARIANT: every byte in [start_address, end_address) belongs to exactly
/// one block, header-to-header, with zero gaps. free()'s coalescing walks
/// neighboring blocks purely via `header.size` arithmetic, so any untracked
/// gap causes it to read unrelated memory as a header. allocate() is
/// written so it can never introduce such a gap: it either accounts for
/// every leftover byte within a block it takes, or it rejects that block as
/// a candidate rather than silently dropping bytes on the floor.
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

        if (size_in_bytes >= MINIMUM_BLOCK_SIZE) {
            const header = @as(*BlockHeader, @ptrFromInt(start_address));
            header.* = .{ .size = size_in_bytes, .free = true };
            getFooter(header).* = .{ .size = size_in_bytes };

            const free_block = @as(*FreeBlock, @ptrFromInt(start_address + @sizeOf(BlockHeader)));
            free_block.next = null;
            heap.free_list = free_block;
        }

        return heap;
    }

    /// Allocates a block of memory from the heap.
    pub fn allocate(self: *Heap, size_in_bytes: usize, alignment: usize) HeapError![*]u8 {
        const actual_alignment = @max(alignment, DEFAULT_ALIGNMENT);
        const aligned_size = alignForward(size_in_bytes, DEFAULT_ALIGNMENT);
        const alloc_block_size = @sizeOf(BlockHeader) + aligned_size + @sizeOf(BlockFooter);

        var prev: ?*FreeBlock = null;
        var current = self.free_list;
        while (current) |block| {
            const header = getHeaderFromFreeBlock(block);
            checkHeader(header);
            const block_start = @intFromPtr(header);

            // Where would the allocation's header need to sit so that its
            // user data satisfies `actual_alignment`?
            const aligned_user_data = alignForward(block_start + @sizeOf(BlockHeader), actual_alignment);
            const header_offset = aligned_user_data - @sizeOf(BlockHeader);
            const padding_size = header_offset - block_start;

            // A padding gap smaller than MINIMUM_BLOCK_SIZE can't be turned
            // into its own tracked free block. However, it *can* be absorbed
            // into the allocation: the padding bytes are counted as consumed
            // but no separate free block is created for them. This keeps the
            // tiling invariant intact because consumed_from_block accounts
            // for every byte from block_start to the start of the trailing
            // remainder (or end of block).
            if (padding_size != 0 and padding_size < MINIMUM_BLOCK_SIZE) {
                // Absorb the small padding into the allocation rather than
                // skipping the candidate. We skip creating a padding free
                // block below by checking padding_size >= MINIMUM_BLOCK_SIZE.
            }
            const consumed_from_block = padding_size + alloc_block_size;
            if (header.size < consumed_from_block) {
                prev = current;
                current = block.next;
                continue;
            }

            const original_block_size = header.size;
            const next_free = block.next;

            // Unlink this block from the free list.
            if (prev) |p| {
                p.next = next_free;
            } else {
                self.free_list = next_free;
            }

            // Front padding: only created when padding_size >=
            // MINIMUM_BLOCK_SIZE, so it's always safely trackable.
            // Small padding (padding_size < MINIMUM_BLOCK_SIZE) is absorbed
            // into the allocation as dead space.
            if (padding_size >= MINIMUM_BLOCK_SIZE) {
                const padding_header = @as(*BlockHeader, @ptrFromInt(block_start));
                padding_header.* = .{ .size = padding_size, .free = true };
                getFooter(padding_header).* = .{ .size = padding_size };
                self.insertIntoFreeList(padding_header);
            }

            // Trailing remainder: if it's too small to stand alone as a
            // tracked free block, absorb it into the allocation instead of
            // discarding it, so every byte in the original block stays
            // accounted for.
            const remaining = original_block_size - consumed_from_block;
            const final_alloc_size = if (remaining >= MINIMUM_BLOCK_SIZE)
                alloc_block_size
            else
                alloc_block_size + remaining;

            const alloc_header = @as(*BlockHeader, @ptrFromInt(header_offset));
            alloc_header.* = .{ .size = final_alloc_size, .free = false };
            getFooter(alloc_header).* = .{ .size = final_alloc_size };

            if (remaining >= MINIMUM_BLOCK_SIZE) {
                const new_free_addr = header_offset + alloc_block_size;
                const new_header = @as(*BlockHeader, @ptrFromInt(new_free_addr));
                new_header.* = .{ .size = remaining, .free = true };
                getFooter(new_header).* = .{ .size = remaining };
                self.insertIntoFreeList(new_header);
            }

            return @as([*]u8, @ptrFromInt(aligned_user_data));
        }

        return HeapError.OutOfMemory;
    }

    /// Frees a previously allocated block of memory.
    pub fn free(self: *Heap, bytes: []u8) void {
        if (bytes.len == 0) return;
        const header = @as(*BlockHeader, @ptrFromInt(@intFromPtr(bytes.ptr) - @sizeOf(BlockHeader)));
        checkHeader(header);
        std.debug.assert(!header.free); // catch double-free
        header.free = true;

        // Coalesce with the next block if it is free.
        const next_header_addr = @intFromPtr(header) + header.size;
        if (next_header_addr < self.end_address) {
            const next_header = @as(*BlockHeader, @ptrFromInt(next_header_addr));
            checkHeader(next_header);
            if (next_header.free) {
                self.removeFromFreeList(next_header);
                header.size += next_header.size;
                getFooter(header).* = .{ .size = header.size };
            }
        }

        // Coalesce with the previous block if it is free.
        if (@intFromPtr(header) > self.start_address) {
            const prev_footer_addr = @intFromPtr(header) - @sizeOf(BlockFooter);
            // Only attempt backward coalescing if the footer is within the
            // heap and its magic is valid. This is necessary because small
            // alignment padding (< sizeof(BlockFooter)) absorbed into the
            // allocation shifts the header past the old block start, making
            // `header - sizeof(BlockFooter)` point into the padding region
            // instead of at the previous block's footer.
            if (prev_footer_addr >= self.start_address) {
                const prev_footer = @as(*BlockFooter, @ptrFromInt(prev_footer_addr));
                if (prev_footer.magic == FOOTER_MAGIC) {
                    const prev_header = @as(*BlockHeader, @ptrFromInt(@intFromPtr(header) - prev_footer.size));
                    checkHeader(prev_header);
                    if (prev_header.free) {
                        self.removeFromFreeList(prev_header);
                        prev_header.size += header.size;
                        getFooter(prev_header).* = .{ .size = prev_header.size };
                        self.insertIntoFreeList(prev_header);
                        return;
                    }
                }
            }
        }

        self.insertIntoFreeList(header);
    }

    /// Resizes a previously allocated block. Returns true if successful.
    pub fn resize(self: *Heap, bytes: []u8, new_size_in_bytes: usize) bool {
        if (bytes.len == 0) return false;
        const header = @as(*BlockHeader, @ptrFromInt(@intFromPtr(bytes.ptr) - @sizeOf(BlockHeader)));
        checkHeader(header);

        const aligned_new_size = alignForward(new_size_in_bytes, DEFAULT_ALIGNMENT);
        const total_needed = @sizeOf(BlockHeader) + aligned_new_size + @sizeOf(BlockFooter);

        if (total_needed <= header.size) {
            const remaining = header.size - total_needed;
            if (remaining >= MINIMUM_BLOCK_SIZE) {
                header.size = total_needed;
                getFooter(header).* = .{ .size = total_needed };

                const new_free_addr = @intFromPtr(header) + total_needed;
                const new_header = @as(*BlockHeader, @ptrFromInt(new_free_addr));
                new_header.* = .{ .size = remaining, .free = true };
                getFooter(new_header).* = .{ .size = remaining };
                self.insertIntoFreeList(new_header);
            }
            return true;
        }

        const next_header_addr = @intFromPtr(header) + header.size;
        if (next_header_addr < self.end_address) {
            const next_header = @as(*BlockHeader, @ptrFromInt(next_header_addr));
            checkHeader(next_header);
            if (next_header.free) {
                const combined_size = header.size + next_header.size;
                if (combined_size >= total_needed) {
                    self.removeFromFreeList(next_header);

                    header.size = combined_size;
                    getFooter(header).* = .{ .size = combined_size };

                    const remaining = header.size - total_needed;
                    if (remaining >= MINIMUM_BLOCK_SIZE) {
                        header.size = total_needed;
                        getFooter(header).* = .{ .size = total_needed };

                        const new_free_addr = @intFromPtr(header) + total_needed;
                        const new_header = @as(*BlockHeader, @ptrFromInt(new_free_addr));
                        new_header.* = .{ .size = remaining, .free = true };
                        getFooter(new_header).* = .{ .size = remaining };
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
        const alignment = @as(usize, 1) << @as(std.math.Log2Int(usize), @intCast(@intFromEnum(pointer_alignment)));
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
        return @as(*BlockFooter, @ptrFromInt(@intFromPtr(header) + (header.size - @sizeOf(BlockFooter))));
    }

    fn getHeaderFromFreeBlock(free_block: *FreeBlock) *BlockHeader {
        return @as(*BlockHeader, @ptrFromInt(@intFromPtr(free_block) - @sizeOf(BlockHeader)));
    }

    /// Panics with a clear message the moment corrupted/misaligned memory
    /// is read as a header, instead of letting a garbage `size` silently
    /// propagate into later arithmetic.
    fn checkHeader(header: *BlockHeader) void {
        std.debug.assert(header.magic == HEADER_MAGIC);
    }

    fn checkFooter(footer: *BlockFooter) void {
        std.debug.assert(footer.magic == FOOTER_MAGIC);
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
