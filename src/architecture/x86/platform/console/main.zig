const std = @import("std");
const LogLevels = @import("arch").LogLevels;

const TEXT_MODE_WIDTH: u16 = 80;
const TEXT_MODE_HEIGHT: u16 = 25;
const TEXT_MODE_BUFFER_SIZE = TEXT_MODE_WIDTH * TEXT_MODE_HEIGHT;

const MAX_ROW_INDEX = TEXT_MODE_HEIGHT - 1;
const MAX_COLUMN_INDEX = TEXT_MODE_WIDTH - 1;

const buffer_pointer: *volatile [TEXT_MODE_BUFFER_SIZE]u16 = @ptrFromInt(0xC00B8000);

var row: u8 = 0;
var column: u8 = 0;

const TextColor = enum(u4) {
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
    @memset(buffer_pointer[0..TEXT_MODE_BUFFER_SIZE], @intFromEnum(TextColor.BLACK));
}

pub fn print(string: []const u8) void {
    const string_ptr = string.ptr;
    for (0..string.len) |i| {
        writeChar(string_ptr[i], LogLevels.infoText);
    }
}

pub fn printLog(string: []const u8, logLevel: LogLevels) void {
    const string_ptr = string.ptr;
    for (0..string.len) |i| {
        writeChar(string_ptr[i], logLevel);
    }
}

fn logLevelToColor(logLevel: LogLevels) TextColor {
    return switch (logLevel) {
        LogLevels.errorText => TextColor.RED,
        LogLevels.warningText => TextColor.LIGHT_RED,
        LogLevels.noticeText => TextColor.GREEN,
        LogLevels.infoText => TextColor.WHITE,
        LogLevels.debugText => TextColor.LIGHT_GRAY,
    };
}

fn putChar(x_position: u8, y_position: u8, character: u8, logLevel: LogLevels) void {
    if (x_position > MAX_COLUMN_INDEX) {
        nextLine();
    }

    buffer_pointer[(y_position * TEXT_MODE_WIDTH) + x_position] = makeChar(character, logLevel);

    column += 1;
}

fn writeChar(character: u8, logLevel: LogLevels) void {
    if (character == '\n') {
        nextLine();
        return;
    }

    if (row > MAX_ROW_INDEX) {
        scrollLine();
    }

    putChar(column, row, character, logLevel);
}

fn makeChar(character: u8, logLevel: LogLevels) u16 {
    const color = logLevelToColor(logLevel);
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
        buffer_pointer[i] = @intFromEnum(TextColor.BLACK);
    }

    row = MAX_ROW_INDEX;
}
