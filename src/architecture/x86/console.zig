const console = @import("../architecture.zig").Arch.Console;
const std = @import("std");

const TEXT_MODE_WIDTH: u16 = 80;
const TEXT_MODE_HEIGHT: u16 = 25;
const TEXT_MODE_BUFFER_SIZE = TEXT_MODE_WIDTH * TEXT_MODE_HEIGHT;

const MAX_ROW_INDEX = TEXT_MODE_HEIGHT - 1;
const MAX_COLUMN_INDEX = TEXT_MODE_WIDTH - 1;

const buffer_pointer: *volatile [TEXT_MODE_BUFFER_SIZE]u16 = @ptrFromInt(0xC00B8000);

var row: u8 = 0;
var column: u8 = 0;

TextColor: enum(u8) {
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
},

pub fn Console() console {
    return console{
        logLevel.traceText = TextColor.LIGHT_GRAY;
        logLevel.infoText = TextColor.WHITE;
        logLevel.warnText = TextColor.YELLOW;
        logLevel.errorText = TextColor.RED;
        logLevel.fatalText = TextColor.RED;

        .initialize = struct {
            fn initialize() void {
                row = 0;
                column = 0;
                @memset(buffer_pointer[0..TEXT_MODE_BUFFER_SIZE], makeChar(' ', console.TextColor.BLACK));
            }
        }.initialize,

        .print = struct {
            fn print(string: []const u8) void {
                const string_ptr = string.ptr;
                for (0..string.len) |i| {
                    writeChar(string_ptr[i], TextColor.WHITE);
                }
            }
        }.print,

        .printColor = struct {
            fn printColor(string: []const u8, color: console.logLevel) void {
                const string_ptr = string.ptr;
                for (0..string.len) |i| {
                    writeChar(string_ptr[i], color);
                }
            }
        }.printColor,
    };
}

fn putChar(x_position: u8, y_position: u8, character: u8, color: console.logLevel) void {
    if (x_position > MAX_COLUMN_INDEX) {
        nextLine();
    }

    buffer_pointer[(y_position * TEXT_MODE_WIDTH) + x_position] = makeChar(character, color);

    column += 1;
}

fn writeChar(character: u8, color: console.logLevel) void {
    if (character == '\n') {
        nextLine();
        return;
    }

    if (row > MAX_ROW_INDEX) {
        scrollLine();
    }

    putChar(column, row, character, color);
}

fn makeChar(character: u8, color: console.logLevel) u16 {
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
        buffer_pointer[i] = makeChar(' ', TextColor.BLACK);
    }

    row = MAX_ROW_INDEX;
}
