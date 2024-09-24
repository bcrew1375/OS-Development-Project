test "terminal_initialize" {
    terminal_initialize();

    for (TEXT_MODE_MEMORY.buffer.*) |byte| {
        try std.testing.expectEqual(@as(u16, 0), byte);
    }
}
