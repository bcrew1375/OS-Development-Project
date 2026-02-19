const time = @import("../architecture.zig").Arch.Time;

pub fn Time() time {
    return time{
        .setupTimer = struct {
            fn setupTimer(frequency: usize) void {
                _ = frequency;
            }
        }.setupTimer,
    };
}
