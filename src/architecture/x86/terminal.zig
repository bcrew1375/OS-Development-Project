const std = @import("std");

const TEXT_MODE_WIDTH: u16 = 80;
const TEXT_MODE_HEIGHT: u16 = 25;
const TEXT_MODE_BUFFER_SIZE = TEXT_MODE_WIDTH * TEXT_MODE_HEIGHT;

const MAX_ROW_INDEX = TEXT_MODE_HEIGHT - 1;
const MAX_COLUMN_INDEX = TEXT_MODE_WIDTH - 1;

pub const COLOR = enum(u8) {
    BLACK = 0,
    BLUE = 1,
    GREEN = 2,
    CYAN = 3,
    RED = 4,
    MAGENTA = 5,
    BROWN = 6,
    LIGHT_GRAY = 7,
    DARK_GRAY = 8,
    LIGHT_BLUE = 9,
    LIGHT_GREEN = 10,
    LIGHT_CYAN = 11,
    LIGHT_RED = 12,
    LIGHT_MAGENTA = 13,
    YELLOW = 14,
    WHITE = 15,
};

const buffer_pointer: *volatile [TEXT_MODE_BUFFER_SIZE]u16 = @ptrFromInt(0xC00B8000);

var row: u8 = 0;
var column: u8 = 0;

pub fn initialize() void {
    row = 0;
    column = 0;
    @memset(buffer_pointer[0..TEXT_MODE_BUFFER_SIZE], makeChar(' ', COLOR.BLACK));
}

pub fn print(string: []const u8) void {
    const string_ptr = string.ptr;
    for (0..string.len) |i| {
        writeChar(string_ptr[i], COLOR.WHITE);
    }
}

pub fn printColor(string: []const u8, color: COLOR) void {
    const string_ptr = string.ptr;
    for (0..string.len) |i| {
        writeChar(string_ptr[i], color);
    }
}

fn putChar(x_position: u8, y_position: u8, character: u8, color: COLOR) void {
    if (x_position > MAX_COLUMN_INDEX) {
        nextLine();
    }

    buffer_pointer[(y_position * TEXT_MODE_WIDTH) + x_position] = makeChar(character, color);

    column += 1;
}

fn writeChar(character: u8, color: COLOR) void {
    if (character == '\n') {
        nextLine();
        return;
    }

    if (row > MAX_ROW_INDEX) {
        scrollLine();
    }

    putChar(column, row, character, color);
}

fn makeChar(character: u8, color: COLOR) u16 {
    return (@as(u16, @intFromEnum(color)) << 8) | character;
}

fn nextLine() void {
    row += 1;
    column = 0;
}

fn scrollLine() void {
    for (TEXT_MODE_WIDTH..TEXT_MODE_BUFFER_SIZE) |i| {
        buffer_pointer[i - TEXT_MODE_WIDTH] = buffer_pointer[i];
    }

    for ((TEXT_MODE_BUFFER_SIZE - TEXT_MODE_WIDTH)..TEXT_MODE_BUFFER_SIZE) |i| {
        buffer_pointer[i] = makeChar(' ', COLOR.BLACK);
    }

    row = MAX_ROW_INDEX;
}
