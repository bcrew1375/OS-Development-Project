const mmu = @import("../architecture.zig").Arch.Mmu;

const paging = @import("paging.zig");

pub fn Mmu() mmu {
    return mmu{
        .initialize = struct {
            fn initialize() void {
                paging.initialize();
            }
        },
    };
}
