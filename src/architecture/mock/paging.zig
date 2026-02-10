const arch = @import("../architecture.zig").Arch.Paging;

const paging = @import("paging/main.zig");

pub fn Paging() arch {
    return arch{
        .initialize = paging.initialize,
        .getPhysicalAddress = paging.getPhysicalAddress,
        .removeIdentityMapping = paging.removeIdentityMapping,
    };
}
