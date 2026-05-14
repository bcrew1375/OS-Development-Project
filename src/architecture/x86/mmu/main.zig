const arch = @import("arch");
const kernel_common = @import("kernel_common");

const common = @import("common.zig");
const early_boot = @import("early_boot.zig");

pub const initializePaging = @import("early_boot.zig").initializePaging;
pub const getMemoryMap = @import("early_boot.zig").getMemoryMap;
pub const getMaxAvailableAddress = @import("early_boot.zig").getMaxAvailableAddress;

const std = @import("std");

var currentPageTables: *[common.PAGE_TABLES_COUNT][common.ENTRIES_PER_TABLE]common.PageEntry = undefined;
var currentPageDirectory: common.PageDirectory = undefined;

pub fn getPhysicalAddress(virtualAddress: usize) ?usize {
    const page_directory_index = getPageDirectoryIndex(virtualAddress);
    const page_table_index = getPageTableIndex(virtualAddress);
    const offset = virtualAddress & 0xFFF;

    if (!currentPageDirectory[page_directory_index].present) return null;

    const page_table_entry = currentPageTables[page_directory_index][page_table_index];
    if (!page_table_entry.present) return null;

    const physical_address = (@as(usize, page_table_entry.address) << 12) + offset;
    return physical_address;
}

pub fn mapPage(virtualAddress: usize, physicalAddress: usize, flags: arch.PageProtection) arch.MmuError!void {
    const page_directory_index = getPageDirectoryIndex(virtualAddress);
    const page_table_index = getPageTableIndex(virtualAddress);

    if (!currentPageDirectory[page_directory_index].present) {
        return arch.MmuError.PageTableNotPresent;
    }

    currentPageTables[page_directory_index][page_table_index].address = @truncate(physicalAddress >> 12);
    currentPageTables[page_directory_index][page_table_index].present = true;
    currentPageTables[page_directory_index][page_table_index].writeable = flags.write;
    currentPageTables[page_directory_index][page_table_index].user_accessible = flags.user;

    flushTLB(virtualAddress);
}

pub fn mapTable(virtualAddress: usize, physicalAddress: usize) arch.MmuError!void {
    const page_directory_index = getPageDirectoryIndex(virtualAddress);

    if (currentPageDirectory[page_directory_index].present) return;

    currentPageDirectory[page_directory_index].address = @truncate(physicalAddress >> 12);
    currentPageDirectory[page_directory_index].present = true;
    currentPageDirectory[page_directory_index].writeable = true;
    currentPageDirectory[page_directory_index].user_accessible = false;

    // Access the table through the recursive mapping to zero it out.
    const table_virtual_address = common.PAGE_TABLES_BASE + (page_directory_index * common.PAGE_SIZE);
    flushTLB(table_virtual_address);
    @memset(@as([*]u8, @ptrFromInt(table_virtual_address))[0..common.PAGE_SIZE], 0);

    flushTLB(virtualAddress);
}

pub fn unmapPage(virtualAddress: usize) void {
    const page_directory_index = getPageDirectoryIndex(virtualAddress);
    const page_table_index = getPageTableIndex(virtualAddress);

    currentPageTables[page_directory_index][page_table_index].present = false;

    flushTLB(virtualAddress);
}

pub fn getKernelCoreAddress() u64 {
    return common.KERNEL_CORE_VIRTUAL_ADDRESS;
}

pub fn getKernelHeapAddress() u64 {
    return common.KERNEL_HEAP_VIRTUAL_ADDRESS;
}

inline fn flushTLB(virtualAddress: usize) void {
    // Invalidate the TLB entry for this virtual address
    asm volatile ("invlpg (%[address])"
        :
        : [address] "r" (virtualAddress),
        : .{ .memory = true });
}

inline fn getPageDirectoryIndex(virtualAddress: usize) usize {
    return virtualAddress >> 22;
}

inline fn getPageTableIndex(virtualAddress: usize) usize {
    return (virtualAddress >> 12) & 0x3FF;
}
