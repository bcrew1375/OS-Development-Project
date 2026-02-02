const paging_arch = @import("../architecture.zig").Arch.Paging;

const paging = @import("paging.zig");

pub fn Paging() paging_arch {
    return paging_arch{
        .getPhysicalAddress = struct {
            fn getPhysicalAddress(virtual_address: usize) usize {
                paging_arch.getPhysicalAddress(virtual_address);
            }
        }.getPhysicalAddress,
    };
}
