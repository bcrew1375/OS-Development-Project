const std = @import("std");

pub const HeapError = error{
    OutOfMemory,
};

pub const Heap = struct {
    start_address: usize,
    end_address: usize,
    next_address: usize,

    /// Initializes the heap structure with a specific memory region.
    pub fn initialize(start_address: usize, size_in_bytes: usize) Heap {
        return .{
            .start_address = start_address,
            .end_address = start_address + size_in_bytes,
            .next_address = start_address,
        };
    }

    /// Allocates a block of memory from the heap using a bump allocation strategy.
    pub fn allocate(self: *Heap, size_in_bytes: usize, alignment: usize) HeapError![*]u8 {
        const aligned_address = std.mem.alignForward(usize, self.next_address, alignment);
        const end_of_allocation = aligned_address + size_in_bytes;

        if (end_of_allocation > self.end_address) {
            return HeapError.OutOfMemory;
        }

        self.next_address = end_of_allocation;
        return @ptrFromInt(aligned_address);
    }

    /// Returns a standard Zig Allocator interface for this heap.
    pub fn allocator(self: *Heap) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = allocate_vtable_entry,
                .resize = resize_vtable_entry,
                .free = free_vtable_entry,
            },
        };
    }

    fn allocate_vtable_entry(context: *anyopaque, length: usize, pointer_alignment: u8, _: usize) ?[*]u8 {
        const self: *Heap = @ptrCast(@alignCast(context));
        const alignment = @as(usize, 1) << @as(u6, @intCast(pointer_alignment));
        return self.allocate(length, alignment) catch null;
    }

    fn resize_vtable_entry(_: *anyopaque, _: []u8, _: u8, _: usize, _: usize) bool {
        // Bump allocators do not support resizing existing memory regions.
        return false;
    }

    fn free_vtable_entry(_: *anyopaque, _: []u8, _: u8, _: usize) void {
        // Bump allocators do not support freeing individual memory blocks.
    }
};
