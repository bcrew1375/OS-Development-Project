const arch = @import("../../architecture.zig");

const std = @import("std");

var memoryMap = arch.MemoryMap{};

var nextAddressSpaceRootValue: usize = 1;
var currentAddressSpaceRoot: arch.AddressSpaceRoot = .{ .value = 0 };

var testRegion: arch.MemoryMapEntry = undefined;
var testRegionHeap: []u8 = undefined;

var heapBase: usize = 0;

// Track mapped page tables so getPhysicalAddress can distinguish
// "table not present" from "page not present".
const MAX_MOCK_TABLES = 32;
const MockTableMapping = struct {
    root_value: usize,
    virtual_address: usize,
    physical_address: usize,
    flags: arch.PageProtection,
};
var tableMappings: [MAX_MOCK_TABLES]MockTableMapping = undefined;
var tableMappingCount: usize = 0;

const MAX_MOCK_PAGE_MAPPINGS = 4096;
pub const MockPageMapping = struct {
    root_value: usize = 0,
    virtual_page: usize,
    physical_page: usize,
    protection: arch.PageProtection,
    present: bool,
};
var pageMappings: [MAX_MOCK_PAGE_MAPPINGS]MockPageMapping = undefined;
var pageMappingCount: usize = 0;

pub fn createAddressSpaceRoot() arch.MmuError!arch.AddressSpaceRoot {
    const address_space_root = arch.AddressSpaceRoot{
        .value = nextAddressSpaceRootValue,
    };

    nextAddressSpaceRootValue += 1;

    return address_space_root;
}

pub fn switchAddressSpaceRoot(root: arch.AddressSpaceRoot) void {
    currentAddressSpaceRoot = root;
}

pub fn getPhysicalAddress(virtualAddress: usize) ?usize {
    return getPhysicalAddressInAddressSpace(currentAddressSpaceRoot, virtualAddress);
}

pub fn getPhysicalAddressInAddressSpace(root: arch.AddressSpaceRoot, virtualAddress: usize) ?usize {
    const pageSize = getPageSize();
    const virtualPage = virtualAddress & ~(pageSize - 1);
    const pageOffset = virtualAddress & (pageSize - 1);

    for (pageMappings[0..pageMappingCount]) |mapping| {
        if (mapping.present and mapping.root_value == root.value and mapping.virtual_page == virtualPage) {
            return mapping.physical_page + pageOffset;
        }
    }

    return null;
}

pub fn isTablePresent(virtualAddress: usize) bool {
    return isTablePresentInAddressSpace(currentAddressSpaceRoot, virtualAddress);
}

pub fn isTablePresentInAddressSpace(root: arch.AddressSpaceRoot, virtualAddress: usize) bool {
    const pageTableRegionSize = getPageTableRegionSize();
    const tableAlignedAddress = virtualAddress & ~(pageTableRegionSize - 1);
    for (tableMappings[0..tableMappingCount]) |mapping| {
        if (mapping.root_value == root.value and mapping.virtual_address == tableAlignedAddress) {
            return true;
        }
    }
    return false;
}

pub fn getMemoryMap() *arch.MemoryMap {
    testRegionHeap = std.heap.page_allocator.alloc(u8, 64 * 1024 * 1024) catch {
        @panic("Mock MMU allocation failed");
    };
    testRegion.address = @intFromPtr(testRegionHeap.ptr);
    testRegion.region_type = arch.MemoryMapRegionType.AVAILABLE;
    testRegion.size = 64 * 1024 * 1024;

    heapBase = @intFromPtr(testRegionHeap.ptr);

    memoryMap.entries[0] = testRegion;
    memoryMap.length = 1;

    return &memoryMap;
}

pub fn mapPage(virtualAddress: usize, physicalAddress: usize, flags: arch.PageProtection) arch.MmuError!void {
    try mapPageInAddressSpace(currentAddressSpaceRoot, virtualAddress, physicalAddress, flags);
}

pub fn mapPageInAddressSpace(root: arch.AddressSpaceRoot, virtualAddress: usize, physicalAddress: usize, flags: arch.PageProtection) arch.MmuError!void {
    if (!isTablePresentInAddressSpace(root, virtualAddress)) {
        return arch.MmuError.PageTableNotPresent;
    }

    const pageSize = getPageSize();
    const virtualPage = virtualAddress & ~(pageSize - 1);
    const physicalPage = physicalAddress & ~(pageSize - 1);

    for (pageMappings[0..pageMappingCount]) |*mapping| {
        if (mapping.root_value == root.value and mapping.virtual_page == virtualPage) {
            mapping.physical_page = physicalPage;
            mapping.protection = flags;
            mapping.present = true;
            return;
        }
    }

    if (pageMappingCount >= MAX_MOCK_PAGE_MAPPINGS) {
        return arch.MmuError.MappingError;
    }

    pageMappings[pageMappingCount] = .{
        .root_value = root.value,
        .virtual_page = virtualPage,
        .physical_page = physicalPage,
        .protection = flags,
        .present = true,
    };
    pageMappingCount += 1;
}

pub fn mapTable(virtualAddress: usize, physicalAddress: usize, flags: arch.PageProtection) arch.MmuError!void {
    try mapTableInAddressSpace(currentAddressSpaceRoot, virtualAddress, physicalAddress, flags);
}

pub fn mapTableInAddressSpace(root: arch.AddressSpaceRoot, virtualAddress: usize, physicalAddress: usize, flags: arch.PageProtection) arch.MmuError!void {
    // Align to the page table region boundary so lookups via
    // isTablePresent (which applies the same alignment) succeed.
    const pageTableRegionSize = getPageTableRegionSize();
    const tableAlignedAddress = virtualAddress & ~(pageTableRegionSize - 1);

    // Check if this table is already mapped.
    for (tableMappings[0..tableMappingCount]) |*mapping| {
        if (mapping.root_value == root.value and mapping.virtual_address == tableAlignedAddress) {
            mapping.flags.write = mapping.flags.write or flags.write;
            mapping.flags.user = mapping.flags.user or flags.user;
            mapping.flags.execute = mapping.flags.execute and flags.execute;
            return;
        }
    }

    if (tableMappingCount >= MAX_MOCK_TABLES) {
        @panic("Mock MMU: too many page tables");
    }

    tableMappings[tableMappingCount] = .{
        .root_value = root.value,
        .virtual_address = tableAlignedAddress,
        .physical_address = physicalAddress,
        .flags = flags,
    };
    tableMappingCount += 1;
}

pub fn getTableProtection(virtualAddress: usize) ?arch.PageProtection {
    const pageTableRegionSize = getPageTableRegionSize();
    const tableAlignedAddress = virtualAddress & ~(pageTableRegionSize - 1);
    for (tableMappings[0..tableMappingCount]) |mapping| {
        if (mapping.root_value == currentAddressSpaceRoot.value and mapping.virtual_address == tableAlignedAddress) {
            return mapping.flags;
        }
    }
    return null;
}

pub fn unmapPage(virtualAddress: usize) void {
    const pageSize = getPageSize();
    const virtualPage = virtualAddress & ~(pageSize - 1);
    for (pageMappings[0..pageMappingCount]) |*mapping| {
        if (mapping.root_value == currentAddressSpaceRoot.value and mapping.virtual_page == virtualPage) {
            mapping.present = false;
            return;
        }
    }
}

pub fn resetForTest() void {
    nextAddressSpaceRootValue = 1;
    currentAddressSpaceRoot = .{ .value = 0 };
    tableMappingCount = 0;
    pageMappingCount = 0;
}

pub fn getMappedPageForTest(virtualAddress: usize) ?MockPageMapping {
    const pageSize = getPageSize();
    const virtualPage = virtualAddress & ~(pageSize - 1);
    for (pageMappings[0..pageMappingCount]) |mapping| {
        if (mapping.root_value == currentAddressSpaceRoot.value and mapping.virtual_page == virtualPage) {
            return mapping;
        }
    }
    return null;
}

pub fn getMaxAvailableAddress() u64 {
    return testRegion.size;
}

pub fn getDirectMapVirtualAddress() u64 {
    return 0;
}

pub fn getDirectMapMaxSize() u64 {
    return 0;
}

pub fn getKernelVirtualAddressStart() u64 {
    return 0xC0000000;
}

pub fn getKernelHeapVirtualAddress() u64 {
    return 0;
}

pub fn getKernelHeapSize() u64 {
    return 0;
}

pub fn getPageSize() usize {
    return 4096;
}

pub fn getPageTableRegionSize() usize {
    return 4096 * 1024;
}
