const TEXT_MODE_WIDTH: u16 = 80;
const TEXT_MODE_HEIGHT: u16 = 25;
const TEXT_MODE_BUFFER_SIZE = TEXT_MODE_WIDTH * TEXT_MODE_HEIGHT;

const MAX_ROW_INDEX = TEXT_MODE_HEIGHT - 1;
const MAX_COLUMN_INDEX = TEXT_MODE_WIDTH - 1;

var row: u8 = 0;
var column: u8 = 0;

pub const TEXT_MODE_MEMORY = struct {
    pub const buffer: *volatile [TEXT_MODE_BUFFER_SIZE]u16 = @ptrFromInt(0xB8000);
};

pub fn initialize() void {
    row = 0;
    column = 0;
    @memset(TEXT_MODE_MEMORY.buffer[0..(TEXT_MODE_BUFFER_SIZE)], make_char(' ', 0));
}

pub fn print(string: []const u8) void {
    for (0..string.len) |i| {
        write_char(string[i], 15);
    }
}

fn put_char(x_position: u8, y_position: u8, character: u8, color: u8) void {
    if ((x_position > MAX_COLUMN_INDEX) or (y_position > MAX_ROW_INDEX)) {
        return;
    }

    TEXT_MODE_MEMORY.buffer.*[(y_position * TEXT_MODE_WIDTH) + x_position] = make_char(character, color);
}

fn write_char(character: u8, color: u8) void {
    if (character == '\n') {
        row += 1;
        column = 0;
        return;
    }

    put_char(column, row, character, color);
    column += 1;

    if (column >= TEXT_MODE_WIDTH) {
        column = 0;
        row += 1;
    }
}

fn make_char(character: u8, color: u8) u16 {
    return (@as(u16, color) << 8) | character;
}
