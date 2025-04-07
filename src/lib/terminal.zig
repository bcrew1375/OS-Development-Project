const kernel_common = @import("kernel_common.zig");

const TEXT_MODE_WIDTH: u16 = 80;
const TEXT_MODE_HEIGHT: u16 = 25;
const TEXT_MODE_BUFFER_SIZE = TEXT_MODE_WIDTH * TEXT_MODE_HEIGHT;

const COLOR = enum(u8) {
    black = 0,
    blue = 1,
    green = 2,
    cyan = 3,
    red = 4,
    magenta = 5,
    brown = 6,
    light_gray = 7,
    dark_gray = 8,
    light_blue = 9,
    light_green = 10,
    light_cyan = 11,
    light_red = 12,
    light_magenta = 13,
    something = 14,
    white = 15,
};

const MAX_ROW_INDEX = TEXT_MODE_HEIGHT - 1;
const MAX_COLUMN_INDEX = TEXT_MODE_WIDTH - 1;

var row: u8 = 0;
var column: u8 = 0;
var printed: u8 = 0;

pub const TEXT_MODE_MEMORY = struct {
    pub const buffer: *volatile [TEXT_MODE_BUFFER_SIZE]u16 = @ptrFromInt(0xB8000);
};

pub fn initialize() void {
    row = 0;
    column = 0;
    @memset(TEXT_MODE_MEMORY.buffer[0..TEXT_MODE_BUFFER_SIZE], makeChar(' ', COLOR.black));
}

pub fn print(string: []const u8) void {
    for (0..string.len) |i| {
        writeChar(string[i], COLOR.white);
    }
}

fn putChar(x_position: u8, y_position: u8, character: u8, color: COLOR) void {
    if ((x_position > MAX_COLUMN_INDEX) or (y_position > MAX_ROW_INDEX)) {
        return;
    }

    TEXT_MODE_MEMORY.buffer.*[(y_position * TEXT_MODE_WIDTH) + x_position] = makeChar(character, color);
}

fn writeChar(character: u8, color: COLOR) void {
    if (character == '\n') {
        row += 1;
        column = 0;
        return;
    }

    putChar(column, row, character, color);
    column += 1;

    if (column >= TEXT_MODE_WIDTH) {
        column = 0;
        row += 1;
    }
}

fn makeChar(character: u8, color: COLOR) u16 {
    return (@as(u16, @intFromEnum(color)) << 8) | character;
}
