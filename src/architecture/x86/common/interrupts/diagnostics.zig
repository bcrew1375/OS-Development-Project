const vectors = @import("vectors.zig");

const TIMER_DIAGNOSTIC_INTERVAL: usize = 100;

pub const Decision = struct {
    print: bool,
    count: usize,
};

var interrupt_seen: [vectors.total]bool = [_]bool{false} ** vectors.total;
var interrupt_counts: [vectors.total]usize = [_]usize{0} ** vectors.total;

/// Records interrupt activity for temporary bring-up diagnostics.
///
/// This intentionally keeps the policy bounded: normal hardware interrupts are
/// first-hit or rate-limited, while CPU exceptions remain visible whenever they
/// occur. The interrupt dispatcher decides where to print the returned data.
pub fn recordInterrupt(vector: usize) Decision {
    var count: usize = 0;
    if (vector < vectors.total) {
        interrupt_counts[vector] +|= 1;
        count = interrupt_counts[vector];
    }

    if (vector < vectors.first_hardware_interrupt and vector != vectors.page_fault) {
        return .{ .print = true, .count = count };
    }

    if (vector == vectors.timer) {
        return .{
            .print = count == 1 or count % TIMER_DIAGNOSTIC_INTERVAL == 0,
            .count = count,
        };
    }

    if (vector < vectors.total and !interrupt_seen[vector]) {
        interrupt_seen[vector] = true;
        return .{ .print = true, .count = count };
    }

    return .{ .print = false, .count = count };
}
