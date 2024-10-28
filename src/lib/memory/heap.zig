const std = @import("std");

const NUM_SIZES = @as(c_int, 32);
const ALIGN = @as(c_int, 4);
const MIN_SIZE = ALIGN_UP(@import("std").zig.c_translation.sizeof(struct_dlist), ALIGN);
const dlist = struct_dlist;
const chunk = struct_chunk;

var free_chunk: [32]struct_dlist = @import("std").mem.zeroes([32]struct_dlist);
var mem_free: usize = 0;
var mem_used: usize = 0;
var mem_meta: usize = 0;
var mem_size: usize = 0;

const struct_dlist = extern struct {
    next: [*c]struct_dlist = @import("std").mem.zeroes([*c]struct_dlist),
    prev: [*c]struct_dlist = @import("std").mem.zeroes([*c]struct_dlist),
};

fn dlist_init(arg_list: [*c]struct_dlist) callconv(.C) void {
    var list = arg_list;
    _ = &list;
    list.*.next = list;
    list.*.prev = list;
}

fn dlist_insert_after(arg_list: [*c]struct_dlist, arg_new_node: [*c]struct_dlist) callconv(.C) void {
    var list = arg_list;
    _ = &list;
    var new_node = arg_new_node;
    _ = &new_node;
    new_node.*.next = list.*.next;
    new_node.*.prev = list;
    list.*.next.*.prev = new_node;
    list.*.next = new_node;
}

fn dlist_insert_before(arg_list: [*c]struct_dlist, arg_new_node: [*c]struct_dlist) callconv(.C) void {
    var list = arg_list;
    _ = &list;
    var new_node = arg_new_node;
    _ = &new_node;
    new_node.*.next = list;
    new_node.*.prev = list.*.prev;
    list.*.prev.*.next = new_node;
    list.*.prev = new_node;
}

fn dlist_remove(arg_list: [*c]struct_dlist) callconv(.C) void {
    var list = arg_list;
    _ = &list;
    list.*.prev.*.next = list.*.next;
    list.*.next.*.prev = list.*.prev;
    list.*.next = list;
    list.*.prev = list;
}

pub const struct_chunk = extern struct {
    all: struct_dlist = @import("std").mem.zeroes(struct_dlist),
    used: c_int = @import("std").mem.zeroes(c_int),
};

fn memory_chunk_slot(arg_size: usize) callconv(.C) usize {
    var size = arg_size;
    _ = &size;
    size = ((size +% @as(usize, @bitCast(@as(c_long, @as(c_int, 4))))) -% @as(usize, @bitCast(@as(c_long, @as(c_int, 1))))) & @as(usize, @bitCast(@as(c_long, ~(@as(c_int, 4) - @as(c_int, 1)))));
    var slot: usize = 0;
    _ = &slot;
    while ((blk: {
        const ref = &size;
        ref.* >>= @intCast(@as(c_int, 1));
        break :blk ref.*;
    }) != 0) {
        slot +%= 1;
    }
    return if (slot > (((@sizeOf(struct_dlist) +% @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 4))))) -% @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 1))))) & @as(c_ulong, @bitCast(@as(c_long, ~(@as(c_int, 4) - @as(c_int, 1))))))) slot -% (((@sizeOf(struct_dlist) +% @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 4))))) -% @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 1))))) & @as(c_ulong, @bitCast(@as(c_long, ~(@as(c_int, 4) - @as(c_int, 1)))))) else @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 0))));
}

fn memory_pool_init(arg_mem: ?*anyopaque, arg_size: usize) void {
    var mem = arg_mem;
    _ = &mem;
    var size = arg_size;
    _ = &size;
    var chunk_1: [*c]struct_chunk = @as([*c]struct_chunk, @ptrCast(@alignCast(mem)));
    //const terminal = @import("../terminal.zig");
    //const kernel_common = @import("../kernel_common.zig");
    //terminal.print(kernel_common.numberToString(@intCast(@intFromPtr(@as([*c]struct_chunk, @ptrCast(@alignCast(mem)))))));
    _ = &chunk_1;
    dlist_init(&chunk_1.*.all);
    dlist_insert_after(&free_chunk[@as(c_uint, @intCast(@as(c_int, 32) - @as(c_int, 1)))], &chunk_1.*.all);
    mem_free = size -% @sizeOf(struct_chunk);
    mem_meta = @sizeOf(struct_chunk);
}

pub fn allocate(arg_size: usize) ?*anyopaque {
    var size = arg_size;
    _ = &size;
    if (size < (((@sizeOf(struct_dlist) +% @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 4))))) -% @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 1))))) & @as(c_ulong, @bitCast(@as(c_long, ~(@as(c_int, 4) - @as(c_int, 1))))))) {
        size = ((@sizeOf(struct_dlist) +% @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 4))))) -% @as(c_ulong, @bitCast(@as(c_long, @as(c_int, 1))))) & @as(c_ulong, @bitCast(@as(c_long, ~(@as(c_int, 4) - @as(c_int, 1)))));
    }
    var slot: usize = memory_chunk_slot(size);
    _ = &slot;
    if (slot >= @as(usize, @bitCast(@as(c_long, @as(c_int, 32))))) return @as(?*anyopaque, @ptrFromInt(@as(c_int, 0)));
    var free_list: [*c]struct_dlist = &free_chunk[slot];
    _ = &free_list;
    if (free_list.*.next == free_list) return @as(?*anyopaque, @ptrFromInt(@as(c_int, 0)));
    var chunk_1: [*c]struct_chunk = @as([*c]struct_chunk, @ptrCast(@alignCast(free_list.*.next)));
    _ = &chunk_1;
    dlist_remove(&chunk_1.*.all);
    chunk_1.*.used = 1;
    mem_free -%= size;
    mem_used +%= size;
    return @as(?*anyopaque, @ptrCast(chunk_1 + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 1)))))));
}

pub fn free(arg_ptr: ?*anyopaque) void {
    var ptr = arg_ptr;
    _ = &ptr;
    if (!(ptr != null)) return;
    var chunk_1: [*c]struct_chunk = @as([*c]struct_chunk, @ptrCast(@alignCast(ptr))) - @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 1)))));
    _ = &chunk_1;
    chunk_1.*.used = 0;
    var size: usize = @sizeOf(struct_chunk) +% @sizeOf(?*anyopaque);
    _ = &size;
    var slot: usize = memory_chunk_slot(size);
    _ = &slot;
    dlist_insert_after(&free_chunk[slot], &chunk_1.*.all);
    mem_used -%= size;
    mem_free +%= size;
}

inline fn ALIGN_UP(val: anytype, alignment: anytype) @TypeOf(((val + alignment) - @as(c_int, 1)) & ~(alignment - @as(c_int, 1))) {
    _ = &val;
    _ = &alignment;
    return ((val + alignment) - @as(c_int, 1)) & ~(alignment - @as(c_int, 1));
}
inline fn CHUNK_DATA(chunk_1: anytype) ?*anyopaque {
    _ = &chunk_1;
    return @import("std").zig.c_translation.cast(?*anyopaque, @import("std").zig.c_translation.cast([*c]struct_chunk, chunk_1) + @as(c_int, 1));
}
inline fn DATA_CHUNK(data: anytype) [*c]struct_chunk {
    _ = &data;
    return @import("std").zig.c_translation.cast([*c]struct_chunk, @import("std").zig.c_translation.cast([*c]struct_chunk, data) - @as(c_int, 1));
}

pub fn initialize(base_address: u32, heap_size: u32) void {
    mem_size = heap_size;
    memory_pool_init(@ptrFromInt(base_address), heap_size);
}

pub fn get_total_size() usize {
    return mem_size;
}

pub fn get_free_size() usize {
    return mem_free;
}
