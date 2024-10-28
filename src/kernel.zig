var allocator = @import("std").heap.GeneralPurposeAllocator(.{}){};

const kernel_common = @import("lib/kernel_common.zig");
const terminal = @import("lib/terminal.zig");
const portio = @import("lib/port-io.zig");
const heap = @import("lib/memory/heap.zig");
const math = @import("std").math;
const print = @import("std").debug.print;

pub const MESSAGE = "Aello,World!\n";

pub export fn main() void {
    const allocation: []u8 = allocator.allocator().alloc(u8, 0x4000000) catch unreachable;
    allocation.ptr[0x1234567] = 0x12;
    heap.initialize(@intCast(@intFromPtr(allocation.ptr)), 0x4000000);

    //kernel_common.kernelInitialize();
    //terminal.initialize();
    //terminal.print(MESSAGE);

    //heap.initialize(0x124689, 0x12345678);
    //const allocation = heap.allocate(20);
    //_ = allocation;
    //terminal.print(kernel_common.numberToString(@intCast(@intFromPtr(&allocation))));
    //var memory_block: [21]i8 = [_]i8{ -10, -9, -8, -7, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }; //[*]i8 = @as([*]i8, @ptrCast(heap.allocate(20)))[0..20];
    //_ = memory_block;
    //const number_buffer: []i8 = @as([*]i8, @ptrCast(heap.allocate(21)))[0..21];

    //for (0..21) |i| {
    //const signed_i: i8 = @intCast(i);
    //_ = i;
    //memory_block[i] = signed_i - 10; //@truncate(@as(i8, @intCast(i - 10))); //@intCast(i - 10);
    //_ = kernel_common.numberToString(@intCast(memory_block[i]));
    //terminal.print("\n");

    //terminal.print(kernel_common.numberToString(@intCast(@intFromPtr(&memory_block))));
    //terminal.print("\n");
    //}

    //heap.free(@ptrCast(memory_block));
}
