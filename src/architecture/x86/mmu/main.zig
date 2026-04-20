const arch = @import("arch");
const multiboot = @import("../boot/main.zig");
const earlyAllocator = @import("../boot/early_allocator.zig");

const std = @import("std");

const CACHE_DISABLED: u8 = 0b00010000;
const WRITE_THROUGH: u8 = 0b00001000;
const ACCESS_FROM_ALL: u8 = 0b00000100;
const IS_WRITEABLE: u8 = 0b00000010;
const IS_PRESENT: u8 = 0b00000001;
const PAGE_SIZE = 4096;

const ENTRIES_PER_DIRECTORY: usize = 1024;
const ENTRIES_PER_TABLE: usize = 1024;
const PAGE_TABLE_COUNT: usize = 1024;
const PAGE_TABLES_BASE: usize = 0xFFC00000;

pub const HIGHER_HALF_ADDRESS = 0xC0000000;
const HIGHER_HALF_INDEX = HIGHER_HALF_ADDRESS / (PAGE_SIZE * ENTRIES_PER_TABLE);

const PageEntry = packed struct {
    flags: u12 = 0,
    address: u20 = 0,
};

const PageDirectory = [ENTRIES_PER_DIRECTORY]PageEntry;
const PageTable = [ENTRIES_PER_TABLE]PageEntry;

const MultibootMemoryMapEntry = extern struct {
    size: u32,
    address: u64,
    length: u64,
    region_type: MultibootMemoryMapEntryTypes,
};

const MultibootMemoryMapEntryTypes = enum(u32) {
    AVAILABLE = 1,
    RESERVED = 2,
    ACPI_RECLAIMABLE = 3,
    ACPI_NVS = 4,
    BAD_MEMORY = 5,
    _,
};

// var pageDirectory: *PageDirectory = undefined;
// var pageTables: *[PAGE_TABLE_COUNT]PageTable = undefined;

// var pageDirectoryEntries: *[ENTRIES_PER_DIRECTORY]PageEntry = undefined; // align(PAGE_SIZE) = [_]PageEntry{.{}} ** ENTRIES_PER_DIRECTORY;
// var pageTable0Entries: *[ENTRIES_PER_TABLE]PageEntry = undefined; // align(PAGE_SIZE) linksection(".multiboot.data") = [_]PageEntry{.{}} ** ENTRIES_PER_TABLE;

var memoryMapEntries: [arch.MAX_MEMORY_MAP_ENTRIES]arch.MemoryMapEntry linksection(".multiboot.data") = [_]arch.MemoryMapEntry{.{}} ** arch.MAX_MEMORY_MAP_ENTRIES;
var memoryMap: arch.MemoryMap linksection(".multiboot.data") = undefined;

pub export fn initialize() linksection(".multiboot.text") void {
    var pageDirectoryEntries: *[ENTRIES_PER_DIRECTORY]PageEntry = @ptrCast(@alignCast(earlyAllocator.allocate(@sizeOf(PageEntry) * ENTRIES_PER_DIRECTORY, PAGE_SIZE, earlyAllocator.ReservedMapEntryType.PERSISTENT)));
    var pageTable0Entries: *[ENTRIES_PER_TABLE]PageEntry = @ptrCast(@alignCast(earlyAllocator.allocate(@sizeOf(PageEntry) * ENTRIES_PER_TABLE, PAGE_SIZE, earlyAllocator.ReservedMapEntryType.PERSISTENT)));

    pageDirectoryEntries[0].address = @truncate(@intFromPtr(pageTable0Entries) >> 12);
    pageDirectoryEntries[0].flags = IS_PRESENT | IS_WRITEABLE;

    pageDirectoryEntries[HIGHER_HALF_INDEX].address = @truncate(@intFromPtr(pageTable0Entries) >> 12);
    pageDirectoryEntries[HIGHER_HALF_INDEX].flags = IS_PRESENT | IS_WRITEABLE;

    // Recursive mapping setup.
    pageDirectoryEntries[ENTRIES_PER_DIRECTORY - 1].address = @truncate(@intFromPtr(pageDirectoryEntries) >> 12);
    pageDirectoryEntries[ENTRIES_PER_DIRECTORY - 1].flags = IS_PRESENT | IS_WRITEABLE;

    // //Only map the first 4 MB.
    for (0..ENTRIES_PER_TABLE) |table_index| {
        pageTable0Entries[table_index].address = @truncate((table_index * PAGE_SIZE) >> 12);
        pageTable0Entries[table_index].flags = IS_PRESENT | IS_WRITEABLE;
    }

    asm volatile (
        \\mov %[pageDirectoryAddress], %eax
        \\mov %eax, %cr3
        \\mov %cr0, %eax
        \\or $0x80010000, %eax
        \\mov %eax, %cr0
        :
        : [pageDirectoryAddress] "{ecx}" (pageDirectoryEntries),
        : .{ .ecx = true, .memory = true });
}

pub fn removeIdentityMapping() void {
    const pageTables: *[PAGE_TABLE_COUNT]PageTable = @ptrFromInt(PAGE_TABLES_BASE);
    var pageDirectory = pageTables[PAGE_TABLE_COUNT - 1];
    pageDirectory[0].address = 0;
    pageDirectory[0].flags = 0;
    asm volatile (
        \\mov %cr3, %eax
        \\mov %eax, %cr3
    );
}

pub fn getPhysicalAddress(virtualAddress: usize) ?usize {
    // const page_directory_index = virtual_address >> 22;
    // const page_table_index = (virtual_address & 0x003FF000) >> 12;
    // const offset = virtual_address & 0xFFF;

    // const page_table_address = @as(usize, @truncate(@as(usize, pageDirectory.*[page_directory_index].address << 12)));
    // const page_table: *PageTable = @ptrFromInt(page_table_address);
    // const page_table_entry = page_table.*[page_table_index];

    // const physical_address = page_table_entry.address + offset;

    // return physical_address;
    _ = virtualAddress;
    return 0;
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

pub fn readMultibootMemoryMap() linksection(".multiboot.text") void {
    memoryMap.entries = &memoryMapEntries;

    var offset: usize = 0;

    for (0..arch.MAX_MEMORY_MAP_ENTRIES) |entry| {
        if (offset >= multiboot.multibootInfo.mmap_length) {
            break;
        }

        const map_entry: *MultibootMemoryMapEntry = @ptrFromInt(multiboot.multibootInfo.mmap_addr + offset);

        memoryMap.entries[entry].address = map_entry.address;
        memoryMap.entries[entry].size = map_entry.length;

        switch (map_entry.region_type) {
            MultibootMemoryMapEntryTypes.AVAILABLE => memoryMap.entries[entry].region_type = arch.MemoryMapEntryType.AVAILABLE,
            MultibootMemoryMapEntryTypes.ACPI_RECLAIMABLE => memoryMap.entries[entry].region_type = arch.MemoryMapEntryType.RECLAIMABLE,
            else => memoryMap.entries[entry].region_type = arch.MemoryMapEntryType.RESERVED,
        }

        memoryMap.length += 1;
        offset += map_entry.size + 4;
    }
}

pub fn getMemoryMap() linksection(".multiboot.text") *arch.MemoryMap {
    readMultibootMemoryMap();
    return &memoryMap;
}
