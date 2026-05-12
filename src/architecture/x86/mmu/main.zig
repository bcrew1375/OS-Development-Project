const arch = @import("arch");
const multiboot = @import("../boot/main.zig");

const std = @import("std");

pub const PAGE_SIZE = 4096;
pub const PAGE_TABLE_REGION_SIZE = PAGE_SIZE * ENTRIES_PER_TABLE;

const KERNEL_CORE_VIRTUAL_ADDRESS = 0xC0000000;
const KERNEL_HEAP_VIRTUAL_ADDRESS = 0xD0000000;

const ENTRIES_PER_DIRECTORY: usize = 1024;
const ENTRIES_PER_TABLE: usize = 1024;

const PAGE_TABLES_COUNT: usize = 1024;
const PAGE_TABLES_BASE = 0xFFC00000;

const HIGHER_HALF_INDEX = KERNEL_CORE_VIRTUAL_ADDRESS / (PAGE_SIZE * ENTRIES_PER_TABLE);

pub const PageEntry = packed struct {
    present: bool = false,
    writeable: bool = false,
    user_accessible: bool = false,
    write_through: bool = false,
    cache_disabled: bool = false,
    accessed: bool = false,
    dirty: bool = false,
    page_size: bool = false,
    global: bool = false,
    available: u3 = 0,
    address: u20 = 0,
};

const PageDirectory = *[ENTRIES_PER_DIRECTORY]PageEntry;
const PageTable = *[ENTRIES_PER_TABLE]PageEntry;

const MultibootMemoryMapEntry = extern struct {
    size: u32,
    address: u64,
    length: u64,
    region_type: MultibootMemoryMapRegionTypes,
};

const MultibootMemoryMapRegionTypes = enum(u32) {
    AVAILABLE = 1,
    RESERVED = 2,
    ACPI_RECLAIMABLE = 3,
    ACPI_NVS = 4,
    BAD_MEMORY = 5,
    _,
};

var pageDirectory: PageDirectory linksection(".multiboot.data") = undefined;
var pageTables: *[PAGE_TABLES_COUNT]PageTable linksection(".multiboot.data") = undefined;

var pageTableCounter: usize linksection(".multiboot.data") = 0;

var memoryMap: arch.MemoryMap linksection(".multiboot.data") = arch.MemoryMap{};

var maxAvailableAddress: u64 = 0;

pub fn initializePaging() linksection(".multiboot.text") !void {
    var pageDirectoryEntries: PageDirectory = @ptrCast(@alignCast(try arch.early_allocator.allocate(@sizeOf(PageEntry) * ENTRIES_PER_DIRECTORY, PAGE_SIZE, arch.ReservedMapRegionType.PERSISTENT)));
    var pageTable0Entries: PageTable = @ptrCast(@alignCast(try arch.early_allocator.allocate(@sizeOf(PageEntry) * ENTRIES_PER_TABLE, PAGE_SIZE, arch.ReservedMapRegionType.PERSISTENT)));

    pageDirectoryEntries[0].address = @truncate(@intFromPtr(pageTable0Entries) >> 12);
    pageDirectoryEntries[0].present = true;
    pageDirectoryEntries[0].writeable = true;

    pageDirectoryEntries[HIGHER_HALF_INDEX].address = @truncate(@intFromPtr(pageTable0Entries) >> 12);
    pageDirectoryEntries[HIGHER_HALF_INDEX].present = true;
    pageDirectoryEntries[HIGHER_HALF_INDEX].writeable = true;

    // Recursive mapping setup.
    pageDirectoryEntries[ENTRIES_PER_DIRECTORY - 1].address = @truncate(@intFromPtr(pageDirectoryEntries) >> 12);
    pageDirectoryEntries[ENTRIES_PER_DIRECTORY - 1].present = true;
    pageDirectoryEntries[ENTRIES_PER_DIRECTORY - 1].writeable = true;

    // //Only map the first 4 MB.
    for (0..ENTRIES_PER_TABLE) |table_index| {
        pageTable0Entries[table_index].address = @truncate((table_index * PAGE_SIZE) >> 12);
        pageTable0Entries[table_index].present = true;
        pageTable0Entries[table_index].writeable = true;
    }

    pageTableCounter += 1;

    asm volatile (
        \\mov %[pageDirectoryAddress], %eax
        \\mov %eax, %cr3
        \\mov %cr0, %eax
        \\or $0x80010000, %eax
        \\mov %eax, %cr0
        :
        : [pageDirectoryAddress] "{ecx}" (pageDirectoryEntries),
        : .{ .ecx = true, .memory = true });

    pageTables = @as(*[PAGE_TABLES_COUNT]PageTable, @ptrFromInt(PAGE_TABLES_BASE));
    pageDirectory = pageDirectoryEntries; //pageTables[PAGE_TABLES_COUNT - 1];
}

pub fn removeIdentityMapping() void {
    pageDirectory[0].address = 0;
    pageDirectory[0].present = false;
    pageDirectory[0].writeable = false;
    pageDirectory[0].accessed = false;

    asm volatile (
        \\mov %cr3, %eax
        \\mov %eax, %cr3
    );

    const pageTablesHigh = @as(*[PAGE_TABLES_COUNT]PageTable, @ptrFromInt(PAGE_TABLES_BASE));
    const pageDirectoryHigh = &pageTables[PAGE_TABLES_COUNT - 1];
    _ = pageTablesHigh;
    _ = pageDirectoryHigh;
}

pub fn getPhysicalAddress(virtualAddress: usize) ?usize {
    const page_directory_index: usize = virtualAddress >> 22;
    const page_table_index: usize = (virtualAddress >> 12) & 0x3FF;
    const offset = virtualAddress & 0xFFF;

    if (!pageDirectory[page_directory_index].present) return null;

    const page_table_entry = pageTables[page_directory_index][page_table_index];
    if (!page_table_entry.present) return null;

    const physical_address = (@as(usize, page_table_entry.address) << 12) + offset;
    return physical_address;
}

//fn free(heap_struct: *const Heap, ptr: *u8) !void {
//    _ = ptr;
//}

fn tableExists(virtualAddress: usize) bool {
    _ = virtualAddress;
    return false;
}

// pub fn allocate(virtual_address: usize, size: usize) !*anyopaque {
//     const total_pages = size / PAGE_SIZE;

//     const start_block = try get_start_block(heap_struct, blocks);
//     mark_blocks_taken(heap_struct, start_block, blocks);

//     const address = block_to_address(heap_struct, start_block);

//     return @ptrFromInt(try allocate_blocks(heap_struct, total_blocks));
// }

// fn allocate_blocks(heap_struct: *const Heap, blocks: usize) !usize {
//     const start_block = try get_start_block(heap_struct, blocks);
//     mark_blocks_taken(heap_struct, start_block, blocks);

//     const address = block_to_address(heap_struct, start_block);
//     return address;
// }

// fn get_start_block(heap_struct: *const Heap, needed_blocks: usize) !usize {
//     var current_block: usize = 0;
//     var start_block: usize = 0;
//     var is_first: bool = true;

//     for (0..heap_struct.table.total_entries) |block_entry| {
//         if (get_entry_type(heap_struct.table.entries[block_entry]) != BLOCK_FREE) {
//             current_block = 0;
//             start_block = 0;
//             is_first = true;
//             continue;
//         }

//         if (is_first) {
//             is_first = false;
//             start_block = block_entry;
//         }

//         current_block += 1;

//         if (current_block == needed_blocks) {
//             return start_block;
//         }
//     }

//     return HeapError.OutOfMemory;
// }

// fn get_entry_type(entry_type: u8) u8 {
//     return entry_type & 0x0F;
// }

// fn block_to_address(heap_struct: *const Heap, start_block: usize) usize {
//     return @intFromPtr(heap_struct.start_address) + (start_block * BLOCK_SIZE);
// }

// fn mark_blocks_taken(heap_struct: *const Heap, start_block: usize, total_blocks: usize) void {
//     const end_block: usize = start_block + total_blocks - 1;

//     var entry: u8 = BLOCK_TAKEN | BLOCK_IS_FIRST;

//     if (total_blocks > 1) {
//         entry |= BLOCK_HAS_NEXT;
//     }

//     for (start_block..(end_block + 1)) |block| {
//         entry = BLOCK_TAKEN;
//         heap_struct.table.entries[block] = entry;
//         if (block != end_block) {
//             entry |= BLOCK_HAS_NEXT;
//         }
//     }
// }

pub fn mapPage(virtualAddress: usize, physicalAddress: usize, flags: arch.PageProtection) arch.MmuError!void {
    const page_directory_index: usize = virtualAddress >> 22;
    const page_table_index: usize = (virtualAddress >> 12) & 0x3FF;

    pageTables[page_directory_index][page_table_index].address = @truncate(physicalAddress >> 12);
    pageTables[page_directory_index][page_table_index].present = true;
    pageTables[page_directory_index][page_table_index].writeable = flags.write;
    pageTables[page_directory_index][page_table_index].user_accessible = flags.user;

    // Invalidate the TLB entry for this virtual address
    asm volatile ("invlpg (%[address])"
        :
        : [address] "r" (virtualAddress),
        : .{ .memory = true });
}

pub fn mapEarlyPageTable(allocation_start_address: usize, mapping_start_address: usize) linksection(".multiboot.text") void {
    pageDirectory[pageTableCounter].address = @truncate(allocation_start_address >> 12);
    pageDirectory[pageTableCounter].present = true;
    pageDirectory[pageTableCounter].writeable = true;

    const page_table: PageTable = @ptrFromInt(allocation_start_address);

    for (0..ENTRIES_PER_TABLE) |table_index| {
        page_table[table_index].address = @truncate((mapping_start_address + (table_index * PAGE_SIZE)) >> 12);
        page_table[table_index].present = true;
        page_table[table_index].writeable = true;
    }

    asm volatile (
        \\mov %cr3, %eax
        \\mov %eax, %cr3
        ::: .{ .eax = true });

    pageTableCounter += 1;
}

pub fn unmapPage(virtualAddress: usize) void {
    const page_directory_index: usize = virtualAddress >> 22;
    const page_table_index: usize = (virtualAddress >> 12) & 0x3FF;

    if (pageDirectory[page_directory_index].present) {
        pageTables[page_directory_index][page_table_index].present = false;

        // Invalidate the TLB entry
        asm volatile ("invlpg (%[address])"
            :
            : [address] "r" (virtualAddress),
            : .{ .memory = true });
    }
}

pub fn readMultibootMemoryMap() linksection(".multiboot.text") void {
    var offset: usize = 0;

    for (0..arch.MAX_MEMORY_MAP_ENTRIES) |entry| {
        if (offset >= multiboot.multibootInfo.mmap_length) {
            break;
        }

        const map_entry: *MultibootMemoryMapEntry = @ptrFromInt(multiboot.multibootInfo.mmap_addr + offset);

        memoryMap.entries[entry].address = map_entry.address;
        memoryMap.entries[entry].size = map_entry.length;

        switch (map_entry.region_type) {
            MultibootMemoryMapRegionTypes.AVAILABLE => memoryMap.entries[entry].region_type = arch.MemoryMapRegionType.AVAILABLE,
            MultibootMemoryMapRegionTypes.ACPI_RECLAIMABLE => memoryMap.entries[entry].region_type = arch.MemoryMapRegionType.RECLAIMABLE,
            else => memoryMap.entries[entry].region_type = arch.MemoryMapRegionType.RESERVED,
        }

        memoryMap.length += 1;
        offset += map_entry.size + 4;
    }
}

pub fn getMemoryMap() linksection(".multiboot.text") *arch.MemoryMap {
    if (memoryMap.length == 0) {
        readMultibootMemoryMap();
    }

    return &memoryMap;
}

pub fn getMaxAvailableAddress() linksection(".multiboot.text") u64 {
    if (maxAvailableAddress == 0) {
        for (memoryMap.entries[0..memoryMap.length]) |entry| {
            if (entry.region_type == arch.MemoryMapRegionType.AVAILABLE) {
                maxAvailableAddress = entry.address + entry.size;
            }
        }
    }

    return maxAvailableAddress;
}

pub fn getKernelCoreAddress() u64 {
    return KERNEL_CORE_VIRTUAL_ADDRESS;
}

pub fn getKernelHeapAddress() u64 {
    return KERNEL_HEAP_VIRTUAL_ADDRESS;
}
