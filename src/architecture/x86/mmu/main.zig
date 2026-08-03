const arch = @import("arch");
const kernel_common = @import("kernel_common");

const common = @import("common.zig");
const early_boot = @import("early_boot.zig");

pub const initializePaging = @import("early_boot.zig").initializePaging;
pub const getMemoryMap = @import("early_boot.zig").getMemoryMap;
pub const getMaxAvailableAddress = @import("early_boot.zig").getMaxAvailableAddress;
pub const getDirectMapVirtualAddress = @import("early_boot.zig").getDirectMapVirtualAddress;
pub const getDirectMapMaxSize = @import("early_boot.zig").getDirectMapMaxSize;

const std = @import("std");

/// Reads the current page directory base from CR3 and returns it as a
/// higher-half virtual address so it can be indexed directly.
inline fn getCurrentPageDirectory() common.PageDirectory {
    var cr3: usize = undefined;
    asm volatile ("mov %cr3, %[cr3]"
        : [cr3] "=r" (cr3),
    );
    return @ptrFromInt(cr3 + common.DIRECT_MAP_VIRTUAL_ADDRESS);
}

pub fn getPhysicalAddress(virtualAddress: usize) ?usize {
    const page_directory_index = getPageDirectoryIndex(virtualAddress);
    const page_table_index = getPageTableIndex(virtualAddress);
    const page_offset = virtualAddress & 0xFFF;

    const page_dir = getCurrentPageDirectory();
    if (!page_dir[page_directory_index].present) return null;

    const page_table = getPageTableFromDirectory(page_dir, page_directory_index);
    const page_table_entry = page_table[page_table_index];
    if (!page_table_entry.present) return null;

    const physical_address = (@as(usize, page_table_entry.address) << 12) + page_offset;
    return physical_address;
}

pub fn isTablePresent(virtualAddress: usize) bool {
    const page_directory_index = getPageDirectoryIndex(virtualAddress);
    const page_dir = getCurrentPageDirectory();
    return page_dir[page_directory_index].present;
}

pub fn mapPage(virtualAddress: usize, physicalAddress: usize, flags: arch.PageProtection) arch.MmuError!void {
    const page_directory_index = getPageDirectoryIndex(virtualAddress);
    const page_table_index = getPageTableIndex(virtualAddress);

    const page_dir = getCurrentPageDirectory();
    if (page_dir[page_directory_index].present) {
        page_dir[page_directory_index].writeable = page_dir[page_directory_index].writeable or flags.write;
        page_dir[page_directory_index].user_accessible = page_dir[page_directory_index].user_accessible or flags.user;
        flushTLB(virtualAddress);
        return;
    }

    const page_table = getPageTableFromDirectory(page_dir, page_directory_index);
    page_table[page_table_index].address = @truncate(physicalAddress >> 12);
    page_table[page_table_index].present = true;
    page_table[page_table_index].writeable = flags.write;
    page_table[page_table_index].user_accessible = flags.user;

    flushTLB(virtualAddress);
}

pub fn mapTable(virtualAddress: usize, physicalAddress: usize, flags: arch.PageProtection) arch.MmuError!void {
    const page_directory_index = getPageDirectoryIndex(virtualAddress);

    const page_dir = getCurrentPageDirectory();
    if (page_dir[page_directory_index].present) {
        page_dir[page_directory_index].writeable = page_dir[page_directory_index].writeable or flags.write;
        page_dir[page_directory_index].user_accessible = page_dir[page_directory_index].user_accessible or flags.user;
        flushTLB(virtualAddress);
        return;
    }

    page_dir[page_directory_index].address = @truncate(physicalAddress >> 12);
    page_dir[page_directory_index].present = true;
    page_dir[page_directory_index].writeable = true;
    page_dir[page_directory_index].user_accessible = flags.user;

    flushTLB(virtualAddress);
}

pub fn unmapPage(virtualAddress: usize) void {
    const page_directory_index = getPageDirectoryIndex(virtualAddress);
    const page_table_index = getPageTableIndex(virtualAddress);

    const page_dir = getCurrentPageDirectory();
    const page_table = getPageTableFromDirectory(page_dir, page_directory_index);
    page_table[page_table_index].present = false;

    flushTLB(virtualAddress);
}

pub fn getKernelVirtualAddressStart() u64 {
    return common.DIRECT_MAP_VIRTUAL_ADDRESS;
}

pub fn getKernelHeapVirtualAddress() u64 {
    return common.KERNEL_HEAP_VIRTUAL_ADDRESS;
}

pub fn getKernelHeapSize() u64 {
    const available_ram = kernel_common.pmm.getTotalAvailableRAM();
    const heap_size_float = @as(f64, @floatFromInt(available_ram)) * common.KERNEL_HEAP_SIZE_RATIO;
    const heap_size_int = @as(u64, @intFromFloat(heap_size_float));
    const aligned_heap_size = std.mem.alignForward(u64, heap_size_int, common.PAGE_SIZE) & std.mem.alignBackward(u64, heap_size_int, common.PAGE_SIZE);
    return aligned_heap_size;
}

pub fn getPageSize() usize {
    return common.PAGE_SIZE;
}

pub fn getPageTableRegionSize() usize {
    return common.PAGE_TABLE_REGION_SIZE;
}

pub fn removeIdentityMapping() void {
    const page_dir = getCurrentPageDirectory();

    const available_ram = getMaxAvailableAddress();
    const direct_map_size = @min(getDirectMapMaxSize(), available_ram);
    const needed_page_tables = @as(usize, @truncate((direct_map_size +| common.PAGE_TABLE_REGION_SIZE -| 1) / common.PAGE_TABLE_REGION_SIZE));

    for (0..needed_page_tables) |table_index| {
        page_dir[table_index].present = false;
        flushTLB(table_index * common.PAGE_TABLE_REGION_SIZE);
    }
}

inline fn flushTLB(virtualAddress: usize) void {
    // Invalidate the TLB entry for this virtual address
    asm volatile ("invlpg (%[address])"
        :
        : [address] "r" (virtualAddress),
        : .{ .memory = true });
}

inline fn getPageTableFromDirectory(page_dir: common.PageDirectory, directoryIndex: usize) common.PageTable {
    const physical_address = @as(usize, page_dir[directoryIndex].address) << 12;
    return @ptrFromInt(physical_address + common.DIRECT_MAP_VIRTUAL_ADDRESS);
}

inline fn getPageDirectoryIndex(virtualAddress: usize) usize {
    return virtualAddress >> 22;
}

inline fn getPageTableIndex(virtualAddress: usize) usize {
    return (virtualAddress >> 12) & 0x3FF;
}

pub inline fn switchPageDirectory(pageDirectoryAddress: common.PageDirectory) void {
    asm volatile (
        \\mov %[pageDirectoryAddress], %eax
        \\mov %eax, %cr3
        :
        : [pageDirectoryAddress] "r" (pageDirectoryAddress),
        : .{ .eax = true, .memory = true });
}
