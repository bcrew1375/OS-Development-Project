const TextColor = @import("arch").TextColor;

const std = @import("std");

const TEXT_MODE_WIDTH: u16 = 80;
const TEXT_MODE_HEIGHT: u16 = 25;
const TEXT_MODE_BUFFER_SIZE = TEXT_MODE_WIDTH * TEXT_MODE_HEIGHT;

const MAX_ROW_INDEX = TEXT_MODE_HEIGHT - 1;
const MAX_COLUMN_INDEX = TEXT_MODE_WIDTH - 1;

const buffer_pointer: *volatile [TEXT_MODE_BUFFER_SIZE]u16 = @ptrFromInt(0xC00B8000);

var row: u8 = 0;
var column: u8 = 0;
var active_color: VGAColor = VGAColor.WHITE;

const VGAColor = enum(u4) {
    BLACK,
    BLUE,
    GREEN,
    CYAN,
    RED,
    MAGENTA,
    BROWN,
    LIGHT_GRAY,
    DARK_GRAY,
    LIGHT_BLUE,
    LIGHT_GREEN,
    LIGHT_CYAN,
    LIGHT_RED,
    LIGHT_MAGENTA,
    YELLOW,
    WHITE,
};

pub fn initialize() void {
    row = 0;
    column = 0;
    active_color = VGAColor.WHITE;
    const clear_char = makeChar(' ', active_color);
    @memset(buffer_pointer[0..TEXT_MODE_BUFFER_SIZE], clear_char);
}

/// A standard Zig Writer that maps to our VGA print logic.
/// This allows the kernel to use std.fmt.format and arch.platform.writer.print(...)
pub const Writer = std.io.GenericWriter(void, error{}, struct {
    fn write(_: void, bytes: []const u8) error{}!usize {
        print(bytes);
        return bytes.len;
    }
}.write);

/// Publicly accessible writer instance
pub const writer = Writer{ .context = {} };

pub fn print(string: []const u8) void {
    for (string) |char| {
        writeChar(char);
    }
}

pub fn setColor(color: TextColor) void {
    active_color = TextColorToVGAColor(color);
}

fn TextColorToVGAColor(text_color: TextColor) VGAColor {
    return switch (text_color) {
        TextColor.BLACK => VGAColor.BLACK,
        TextColor.BLUE => VGAColor.BLUE,
        TextColor.GREEN => VGAColor.GREEN,
        TextColor.CYAN => VGAColor.CYAN,
        TextColor.RED => VGAColor.RED,
        TextColor.MAGENTA => VGAColor.MAGENTA,
        TextColor.BROWN => VGAColor.BROWN,
        TextColor.LIGHT_GRAY => VGAColor.LIGHT_GRAY,
        TextColor.DARK_GRAY => VGAColor.DARK_GRAY,
        TextColor.LIGHT_BLUE => VGAColor.LIGHT_BLUE,
        TextColor.LIGHT_GREEN => VGAColor.LIGHT_GREEN,
        TextColor.LIGHT_CYAN => VGAColor.LIGHT_CYAN,
        TextColor.LIGHT_RED => VGAColor.LIGHT_RED,
        TextColor.LIGHT_MAGENTA => VGAColor.LIGHT_MAGENTA,
        TextColor.YELLOW => VGAColor.YELLOW,
        TextColor.WHITE => VGAColor.WHITE,
    };
}

fn putChar(x_position: u8, y_position: u8, character: u8, color: VGAColor) void {
    // Calculate index based on updated positions
    const safe_x = if (x_position > MAX_COLUMN_INDEX) 0 else x_position;
    const safe_y = if (x_position > MAX_COLUMN_INDEX) y_position + 1 else y_position;

    buffer_pointer[(@as(u32, safe_y) * TEXT_MODE_WIDTH) + safe_x] = makeChar(character, color);

    column += 1;
}

fn writeChar(character: u8) void {
    if (character == '\n') {
        nextLine();
        return;
    }

    if (column > MAX_COLUMN_INDEX) {
        nextLine();
    }

    if (row > MAX_ROW_INDEX) {
        scrollLine();
    }

    putChar(column, row, character, active_color);
}

fn makeChar(character: u8, color: VGAColor) u16 {
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

    const clear_char = makeChar(' ', active_color);
    for ((TEXT_MODE_BUFFER_SIZE - TEXT_MODE_WIDTH)..TEXT_MODE_BUFFER_SIZE) |i| {
        buffer_pointer[i] = clear_char;
    }

    row = MAX_ROW_INDEX;
}
