const kernel_common = @import("kernel_common.zig");
const std = @import("std");

const TEXT_MODE_WIDTH: u16 = 80;
const TEXT_MODE_HEIGHT: u16 = 25;
const TEXT_MODE_BUFFER_SIZE = TEXT_MODE_WIDTH * TEXT_MODE_HEIGHT;

const MAX_ROW_INDEX = TEXT_MODE_HEIGHT - 1;
const MAX_COLUMN_INDEX = TEXT_MODE_WIDTH - 1;

var row: u8 = 0;
var column: u8 = 0;

pub const TEXT_MODE_MEMORY = struct {
    pub var buffer: *volatile [TEXT_MODE_BUFFER_SIZE]u16 = @ptrFromInt(0xB8000);
};

pub fn initialize() void {
    row = 0;
    column = 0;
    @memset(TEXT_MODE_MEMORY.buffer[0..TEXT_MODE_BUFFER_SIZE], makeChar(' ', kernel_common.COLOR.BLACK));
}

pub fn print(string: []const u8) void {
    for (0..string.len) |i| {
        writeChar(string[i], kernel_common.COLOR.WHITE);
    }
}

pub fn printColor(string: []const u8, color: kernel_common.COLOR) void {
    for (0..string.len) |i| {
        writeChar(string[i], color);
    }
}

fn putChar(x_position: u8, y_position: u8, character: u8, color: kernel_common.COLOR) void {
    if (x_position > MAX_COLUMN_INDEX) {
        nextLine();
    }

    TEXT_MODE_MEMORY.buffer.*[(y_position * TEXT_MODE_WIDTH) + x_position] = makeChar(character, color);

    column += 1;
}

fn writeChar(character: u8, color: kernel_common.COLOR) void {
    if (character == '\n') {
        nextLine();
        return;
    }

    if (row > MAX_ROW_INDEX) {
        scrollLine();
    }

    putChar(column, row, character, color);
}

fn makeChar(character: u8, color: kernel_common.COLOR) u16 {
    return (@as(u16, @intFromEnum(color)) << 8) | character;
}

fn nextLine() void {
    row += 1;
    column = 0;
}

fn scrollLine() void {
    for (TEXT_MODE_WIDTH..TEXT_MODE_BUFFER_SIZE) |i| {
        TEXT_MODE_MEMORY.buffer.*[i - TEXT_MODE_WIDTH] = TEXT_MODE_MEMORY.buffer.*[i];
    }

    for ((TEXT_MODE_BUFFER_SIZE - TEXT_MODE_WIDTH)..TEXT_MODE_BUFFER_SIZE) |i| {
        TEXT_MODE_MEMORY.buffer.*[i] = makeChar(' ', kernel_common.COLOR.BLACK);
    }

    row = MAX_ROW_INDEX;
}
