const arch = @import("arch");

const pmm = @import("pmm.zig");

pub const VMMError = error{
    UndefinedAddressSpace,
    OverlappingVirtualMemoryArea,
    UndefinedVirtualMemoryArea,
    OutOfVirtualMemoryAreas,
    InvalidVirtualMemoryAreaRange,
    UnalignedVirtualMemoryArea,
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
    virtual_memory_areas: []VirtualMemoryArea = undefined,
    length: usize = 0,
};

var currentAddressSpace: *AddressSpace = undefined;

pub fn setAddressSpace(addressSpace: *AddressSpace) void {
    currentAddressSpace = addressSpace;
}

pub fn map(addressSpace: *AddressSpace, startAddress: u64, endAddress: u64, memoryPermissions: MemoryPermissions) !void {
    if (addressSpace.virtual_memory_areas.len == 0) {
        return VMMError.UndefinedAddressSpace;
    }

    if (addressSpace.length >= addressSpace.virtual_memory_areas.len) {
        return VMMError.OutOfVirtualMemoryAreas;
    }

    if (startAddress >= endAddress) {
        return VMMError.InvalidVirtualMemoryAreaRange;
    }

    const page_size: u64 = @intCast(arch.mmu.getPageSize());
    if ((startAddress % page_size != 0) or (endAddress % page_size != 0)) {
        return VMMError.UnalignedVirtualMemoryArea;
    }

    for (addressSpace.virtual_memory_areas[0..addressSpace.length]) |vma| {
        if ((startAddress < vma.end_address) and (endAddress > vma.start_address)) {
            return VMMError.OverlappingVirtualMemoryArea;
        }
    }

    addressSpace.virtual_memory_areas[addressSpace.length].start_address = startAddress;
    addressSpace.virtual_memory_areas[addressSpace.length].end_address = endAddress;
    addressSpace.virtual_memory_areas[addressSpace.length].permissions = memoryPermissions;

    addressSpace.length += 1;
}

pub fn unmap(addressSpace: *AddressSpace, startAddress: u64, endAddress: u64) void {
    for (addressSpace.virtual_memory_areas[0..addressSpace.length], 0..) |vma, vmaIndex| {
        if (vma.start_address == startAddress and vma.end_address == endAddress) {
            const pageSize = @as(u64, @intCast(arch.mmu.getPageSize()));
            var pageAddress = startAddress;
            while (pageAddress < endAddress) : (pageAddress += pageSize) {
                arch.mmu.unmapPage(@intCast(pageAddress));
            }

            var shiftIndex = vmaIndex;
            while (shiftIndex < addressSpace.length - 1) : (shiftIndex += 1) {
                addressSpace.virtual_memory_areas[shiftIndex] = addressSpace.virtual_memory_areas[shiftIndex + 1];
            }
            addressSpace.length -= 1;
            return;
        }
    }
}

pub fn faultHandler(faultInfo: arch.FaultInfo) void {
    if (arch.earlyAllocatorActive == true) {
        @panic("Page fault before memory handling initialization!");
    }

    if (faultInfo.present == false) {
        for (currentAddressSpace.virtual_memory_areas[0..currentAddressSpace.length]) |vma| {
            if ((faultInfo.address >= vma.start_address) and (faultInfo.address < vma.end_address)) {
                const pageProtection = arch.PageProtection{
                    .write = vma.permissions.writeable,
                    .user = vma.permissions.user_accessible,
                    .execute = vma.permissions.executable,
                };

                // Page tables are lazily allocated on the first fault to a region.
                // isTablePresent() checks only the page directory entry, so it
                // correctly distinguishes "table missing" from "page not yet mapped".
                const tableAlignedAddress: usize = faultInfo.address & ~(arch.mmu.getPageSize() - 1);

                if (!arch.mmu.isTablePresent(tableAlignedAddress)) {
                    const tablePhysicalAddress = pmm.allocate(1) catch |err| {
                        @panic(@errorName(err));
                    };
                    arch.mmu.mapTable(tableAlignedAddress, tablePhysicalAddress) catch |err| {
                        @panic(@errorName(err));
                    };
                }

                // Allocate a separate physical page for the actual data.
                const dataPhysicalAddress = pmm.allocate(1) catch |err| {
                    @panic(@errorName(err));
                };
                arch.mmu.mapPage(faultInfo.address, dataPhysicalAddress, pageProtection) catch |err| {
                    @panic(@errorName(err));
                };

                // Zero the newly mapped page to prevent stale data from
                // previous allocations from corrupting heap metadata.
                @memset(@as([*]u8, @ptrFromInt(faultInfo.address & ~(arch.mmu.getPageSize() - 1)))[0..arch.mmu.getPageSize()], 0);
                return;
            }
        }
        @panic("Segmentation fault.");
    }
}
