const arch = @import("../architecture.zig").Arch.Paging;

const paging = @import("paging/main.zig");

pub fn Paging() arch {
    return arch{
        .initialize = struct {
            fn initialize() void {
                paging.initialize();
            }
        }.initialize,
        .removeIdentityMapping = paging.removeIdentityMapping,
        .getPhysicalAddress = paging.getPhysicalAddress,
    };
}
