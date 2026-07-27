const std = @import("std");

pub const HeapError = error{
    OutOfMemory,
};

const HEADER_MAGIC: u32 = 0x4845_4150; // "HEAP"
const FOOTER_MAGIC: u32 = 0x464F_4F54; // "FOOT"

/// Header stored at the beginning of every heap block.
///
/// `size` covers the entire block: header, payload area, padding, and footer.
/// `payload_offset` is meaningful for allocated blocks and points from the
/// header address to the user pointer returned by `allocate()`.
pub const BlockHeader = struct {
    magic: u32 = HEADER_MAGIC,
    size: usize,
    free: bool,
    payload_offset: usize = @sizeOf(BlockHeader),
};

pub const BlockFooter = struct {
    magic: u32 = FOOTER_MAGIC,
    size: usize,
};

const FreeBlock = struct {
    next: ?*FreeBlock,
};

const DEFAULT_ALIGNMENT: usize = 8;
const ALLOCATION_TAG_SIZE: usize = @sizeOf(usize);
const MINIMUM_BLOCK_SIZE: usize = alignForward(
    @sizeOf(BlockHeader) + @sizeOf(FreeBlock) + @sizeOf(BlockFooter),
    DEFAULT_ALIGNMENT,
);

const AllocationLayout = struct {
    user_address: usize,
    payload_offset: usize,
    block_size: usize,
};

/// A boundary-tag heap allocator backed by a sorted singly-linked free list.
///
/// Each block has this physical layout:
///
///   [BlockHeader | payload/padding/free-node | BlockFooter]
///
/// Free blocks store their `FreeBlock` node in the payload area immediately
/// after the header. Allocated blocks store a small tag immediately before the
/// returned user pointer so `free()` can recover the block header even when the
/// user pointer was moved forward to satisfy a larger alignment.
pub const Heap = struct {
    start_address: usize,
    end_address: usize,
    free_list: ?*FreeBlock,

    pub fn initialize(start_address: usize, size_in_bytes: usize) Heap {
        var heap = Heap{
            .start_address = start_address,
            .end_address = start_address + size_in_bytes,
            .free_list = null,
        };

        if (size_in_bytes >= MINIMUM_BLOCK_SIZE) {
            const header = initializeBlock(start_address, alignBackward(size_in_bytes, DEFAULT_ALIGNMENT), true, @sizeOf(BlockHeader));
            freeNodeFromHeader(header).next = null;
            heap.free_list = freeNodeFromHeader(header);
        }

        return heap;
    }

    pub fn allocate(self: *Heap, size_in_bytes: usize, alignment: usize) HeapError![*]u8 {
        const actual_alignment = @max(alignment, DEFAULT_ALIGNMENT);

        var previous: ?*FreeBlock = null;
        var current = self.free_list;
        while (current) |free_node| {
            const free_header = headerFromFreeNode(free_node);
            checkHeader(free_header);

            const layout = computeAllocationLayout(@intFromPtr(free_header), size_in_bytes, actual_alignment);
            if (layout.block_size > free_header.size) {
                previous = free_node;
                current = free_node.next;
                continue;
            }

            const original_size = free_header.size;
            self.unlinkFreeNode(previous, free_node);

            const allocation_size = chooseAllocationBlockSize(original_size, layout.block_size);
            const allocated_header = initializeBlock(@intFromPtr(free_header), allocation_size, false, layout.payload_offset);
            writeAllocationTag(allocated_header);

            const trailing_size = original_size - allocation_size;
            if (trailing_size >= MINIMUM_BLOCK_SIZE) {
                const trailing_header = initializeBlock(@intFromPtr(allocated_header) + allocation_size, trailing_size, true, @sizeOf(BlockHeader));
                self.insertIntoFreeList(trailing_header);
            }

            return @as([*]u8, @ptrFromInt(layout.user_address));
        }

        return HeapError.OutOfMemory;
    }

    pub fn free(self: *Heap, bytes: []u8) void {
        if (bytes.len == 0) return;

        var header = getBlockHeaderFromAllocation(bytes);
        std.debug.assert(!header.free);

        header.free = true;
        header.payload_offset = @sizeOf(BlockHeader);

        header = self.coalesceWithNext(header);
        header = self.coalesceWithPrevious(header);
        self.insertIntoFreeList(header);
    }

    pub fn resize(self: *Heap, bytes: []u8, new_size_in_bytes: usize) bool {
        if (bytes.len == 0) return false;

        const header = getBlockHeaderFromAllocation(bytes);
        checkHeader(header);
        std.debug.assert(!header.free);

        const needed_size = requiredBlockSizeForExistingAllocation(header, new_size_in_bytes);
        if (needed_size <= header.size) {
            self.splitAllocatedBlockIfUseful(header, needed_size);
            return true;
        }

        return self.tryGrowIntoNextBlock(header, needed_size);
    }

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

    fn unlinkFreeNode(self: *Heap, previous: ?*FreeBlock, node: *FreeBlock) void {
        if (previous) |previous_node| {
            previous_node.next = node.next;
        } else {
            self.free_list = node.next;
        }
        node.next = null;
    }

    fn removeFromFreeList(self: *Heap, header: *BlockHeader) void {
        const target = freeNodeFromHeader(header);
        var previous: ?*FreeBlock = null;
        var current = self.free_list;

        while (current) |node| {
            if (node == target) {
                self.unlinkFreeNode(previous, node);
                return;
            }
            previous = node;
            current = node.next;
        }
    }

    fn insertIntoFreeList(self: *Heap, header: *BlockHeader) void {
        checkHeader(header);
        std.debug.assert(header.free);

        const node = freeNodeFromHeader(header);
        const address = @intFromPtr(header);

        var previous: ?*FreeBlock = null;
        var current = self.free_list;
        while (current) |current_node| {
            const current_address = @intFromPtr(headerFromFreeNode(current_node));
            if (address < current_address) break;
            previous = current_node;
            current = current_node.next;
        }

        node.next = current;
        if (previous) |previous_node| {
            previous_node.next = node;
        } else {
            self.free_list = node;
        }
    }

    fn coalesceWithNext(self: *Heap, header: *BlockHeader) *BlockHeader {
        const next_address = @intFromPtr(header) + header.size;
        if (next_address >= self.end_address) return header;

        const next_header = @as(*BlockHeader, @ptrFromInt(next_address));
        checkHeader(next_header);
        if (!next_header.free) return header;

        self.removeFromFreeList(next_header);
        return initializeBlock(@intFromPtr(header), header.size + next_header.size, true, @sizeOf(BlockHeader));
    }

    fn coalesceWithPrevious(self: *Heap, header: *BlockHeader) *BlockHeader {
        const header_address = @intFromPtr(header);
        if (header_address == self.start_address) return header;

        const footer_address = header_address - @sizeOf(BlockFooter);
        if (footer_address < self.start_address) return header;

        const previous_footer = @as(*BlockFooter, @ptrFromInt(footer_address));
        if (previous_footer.magic != FOOTER_MAGIC) return header;

        const previous_address = header_address - previous_footer.size;
        if (previous_address < self.start_address) return header;

        const previous_header = @as(*BlockHeader, @ptrFromInt(previous_address));
        checkHeader(previous_header);
        if (!previous_header.free) return header;

        self.removeFromFreeList(previous_header);
        return initializeBlock(previous_address, previous_header.size + header.size, true, @sizeOf(BlockHeader));
    }

    fn splitAllocatedBlockIfUseful(self: *Heap, header: *BlockHeader, needed_size: usize) void {
        const original_size = header.size;
        if (original_size < needed_size + MINIMUM_BLOCK_SIZE) return;

        _ = initializeBlock(@intFromPtr(header), needed_size, false, header.payload_offset);
        writeAllocationTag(header);

        const remainder_header = initializeBlock(@intFromPtr(header) + needed_size, original_size - needed_size, true, @sizeOf(BlockHeader));
        self.insertIntoFreeList(remainder_header);
    }

    fn tryGrowIntoNextBlock(self: *Heap, header: *BlockHeader, needed_size: usize) bool {
        const next_address = @intFromPtr(header) + header.size;
        if (next_address >= self.end_address) return false;

        const next_header = @as(*BlockHeader, @ptrFromInt(next_address));
        checkHeader(next_header);
        if (!next_header.free) return false;

        const combined_size = header.size + next_header.size;
        if (combined_size < needed_size) return false;

        self.removeFromFreeList(next_header);

        const allocation_size = chooseAllocationBlockSize(combined_size, needed_size);
        _ = initializeBlock(@intFromPtr(header), allocation_size, false, header.payload_offset);
        writeAllocationTag(header);

        const remainder_size = combined_size - allocation_size;
        if (remainder_size >= MINIMUM_BLOCK_SIZE) {
            const remainder_header = initializeBlock(@intFromPtr(header) + allocation_size, remainder_size, true, @sizeOf(BlockHeader));
            self.insertIntoFreeList(remainder_header);
        }

        return true;
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
        if (self.resize(bytes, new_length)) return bytes.ptr;
        return null;
    }

    fn freeVtableEntry(context: *anyopaque, bytes: []u8, _: std.mem.Alignment, _: usize) void {
        const self: *Heap = @ptrCast(@alignCast(context));
        self.free(bytes);
    }
};

pub fn getBlockHeaderFromAllocation(bytes: []u8) *BlockHeader {
    const tag_address = @intFromPtr(bytes.ptr) - ALLOCATION_TAG_SIZE;
    const header = @as(*BlockHeader, @ptrFromInt(@as(*usize, @ptrFromInt(tag_address)).*));
    checkHeader(header);
    return header;
}

fn computeAllocationLayout(block_address: usize, size_in_bytes: usize, alignment: usize) AllocationLayout {
    const aligned_size = alignForward(size_in_bytes, DEFAULT_ALIGNMENT);
    const user_address = alignForward(block_address + @sizeOf(BlockHeader) + ALLOCATION_TAG_SIZE, alignment);
    const payload_offset = user_address - block_address;
    const block_size = alignForward(payload_offset + aligned_size + @sizeOf(BlockFooter), DEFAULT_ALIGNMENT);

    return .{
        .user_address = user_address,
        .payload_offset = payload_offset,
        .block_size = block_size,
    };
}

fn requiredBlockSizeForExistingAllocation(header: *const BlockHeader, new_size_in_bytes: usize) usize {
    const aligned_size = alignForward(new_size_in_bytes, DEFAULT_ALIGNMENT);
    return alignForward(header.payload_offset + aligned_size + @sizeOf(BlockFooter), DEFAULT_ALIGNMENT);
}

fn chooseAllocationBlockSize(available_size: usize, requested_size: usize) usize {
    const remainder_size = available_size - requested_size;
    return if (remainder_size >= MINIMUM_BLOCK_SIZE) requested_size else available_size;
}

fn initializeBlock(address: usize, size: usize, free: bool, payload_offset: usize) *BlockHeader {
    const header = @as(*BlockHeader, @ptrFromInt(address));
    header.* = .{
        .size = size,
        .free = free,
        .payload_offset = payload_offset,
    };
    footerFromHeader(header).* = .{ .size = size };
    return header;
}

fn writeAllocationTag(header: *BlockHeader) void {
    const tag_address = @intFromPtr(header) + header.payload_offset - ALLOCATION_TAG_SIZE;
    @as(*usize, @ptrFromInt(tag_address)).* = @intFromPtr(header);
}

fn footerFromHeader(header: *const BlockHeader) *BlockFooter {
    return @as(*BlockFooter, @ptrFromInt(@intFromPtr(header) + header.size - @sizeOf(BlockFooter)));
}

fn freeNodeFromHeader(header: *BlockHeader) *FreeBlock {
    return @as(*FreeBlock, @ptrFromInt(@intFromPtr(header) + @sizeOf(BlockHeader)));
}

fn headerFromFreeNode(node: *FreeBlock) *BlockHeader {
    return @as(*BlockHeader, @ptrFromInt(@intFromPtr(node) - @sizeOf(BlockHeader)));
}

fn checkHeader(header: *const BlockHeader) void {
    std.debug.assert(header.magic == HEADER_MAGIC);
}

fn alignForward(address: usize, alignment: usize) usize {
    return (address + alignment - 1) & ~(alignment - 1);
}

fn alignBackward(address: usize, alignment: usize) usize {
    return address & ~(alignment - 1);
}
