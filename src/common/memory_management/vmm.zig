const arch = @import("arch");

const KERNEL_CORE_START_ADDRESS: u64 = arch.mmu.getKernelCoreAddress();
const KERNEL_CORE_END_ADDRESS: u64 = arch.mmu.getKernelCoreAddress();
const KERNEL_HEAP_START_ADDRESS: u64 = arch.mmu.getKernelHeapAddress();
const KERNEL_HEAP_END_ADDRESS: u64 = arch.mmu.getKernelHeapAddress();

/// Defines the access rights for a specific virtual memory mapping.
pub const MemoryPermissions = enum {
    readable,
    writeable,
    executable,
    user_accessible,
};

pub const VirtualMemoryArea = struct {
    start_address: u64,
    end_address: u64,
    permissions: MemoryPermissions,
};

pub const AddressSpace = struct {
    VMAList: []VirtualMemoryArea = undefined,
    length: usize = undefined,
};

pub fn initialize() void {}

pub fn faultHandler(faultInfo: arch.FaultInfo) void {
    if (faultInfo.present == false) {}
}
