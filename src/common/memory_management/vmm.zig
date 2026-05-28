const arch = @import("arch");

const pmm = @import("kernel_common").pmm;

const VMMError = error{
    UndefinedAddressSpace,
    OverlappingVirtualMemoryArea,
    UndefinedVirtualMemoryArea,
    NoTransientMappingSlots,
};

/// Defines the access rights for a specific virtual memory mapping.
pub const MemoryPermissions = struct {
    readable: bool,
    writeable: bool,
    executable: bool,
    user_accessible: bool,
};

pub const VirtualMemoryArea = struct {
    start_address: u64 = undefined,
    end_address: u64 = undefined,
    permissions: MemoryPermissions = undefined,
};

pub const AddressSpace = struct {
    VMAList: []VirtualMemoryArea = undefined,
    length: usize = 0,
};

var currentAddressSpace: *AddressSpace = undefined;

/// TransientMapping provides a way to temporarily access physical memory
/// that is not covered by the Direct Physical Map.
/// This avoids the "Linux highmem mess" by using a scoped lifecycle.
pub const TransientMapping = struct {
    virtual_address: usize,
    size: usize,

    pub fn init(physical_address: usize, size: usize, permissions: MemoryPermissions) !TransientMapping {
        // In a real implementation, this would find a free slot in a reserved
        // "Transient Window" of the virtual address space (e.g., 0xF0000000).
        const vaddr = try arch.mmu.mapTransient(physical_address, size, permissions);
        return TransientMapping{
            .virtual_address = vaddr,
            .size = size,
        };
    }

    pub fn deinit(self: *TransientMapping) void {
        arch.mmu.unmapTransient(self.virtual_address, self.size);
    }

    /// Returns a typed pointer to the mapped memory.
    pub fn getPointer(self: TransientMapping, comptime T: type) *T {
        return @ptrFromInt(self.virtual_address);
    }
};

pub fn setAddressSpace(addressSpace: *AddressSpace) void {
    currentAddressSpace = addressSpace;
}

pub fn map(addressSpace: *AddressSpace, startAddress: u64, endAddress: u64, memoryPermissions: MemoryPermissions) !void {
    if (addressSpace.VMAList.len == 0) {
        return VMMError.UndefinedAddressSpace;
    }

    for (addressSpace.VMAList[0..addressSpace.length]) |vma| {
        if ((startAddress < vma.end_address) and (endAddress > vma.start_address)) {
            return VMMError.OverlappingVirtualMemoryArea;
        }
    }

    addressSpace.VMAList[addressSpace.length].start_address = startAddress;
    addressSpace.VMAList[addressSpace.length].end_address = endAddress;
    addressSpace.VMAList[addressSpace.length].permissions = memoryPermissions;

    addressSpace.length += 1;
}

pub fn faultHandler(faultInfo: arch.FaultInfo) void {
    if (arch.earlyAllocatorActive == true) {
        @panic("Page fault before memory handling initialization!");
    }

    if (faultInfo.present == false) {
        for (currentAddressSpace.VMAList[0..currentAddressSpace.length]) |vma| {
            if ((faultInfo.address >= vma.start_address) and (faultInfo.address < vma.end_address)) {
                const physical_address = pmm.allocate(1) catch |err| {
                    @panic(@errorName(err));
                };

                const page_protection = arch.PageProtection{
                    .write = vma.permissions.writeable,
                    .user = vma.permissions.user_accessible,
                    .execute = vma.permissions.executable,
                };

                mapping_retry: while (true) {
                    arch.mmu.mapPage(faultInfo.address, physical_address, page_protection) catch |err| {
                        if (err == arch.MmuError.PageTableNotPresent) {
                            const table_physical_address = pmm.allocate(1) catch |alloc_err| {
                                @panic(@errorName(alloc_err));
                            };

                            arch.mmu.mapTable(faultInfo.address, table_physical_address) catch |table_err| {
                                @panic(@errorName(table_err));
                            };

                            continue :mapping_retry;
                        }
                        @panic(@errorName(err));
                    };

                    return;
                }
            }
        }
        @panic("Segmentation fault.");
    }
}
