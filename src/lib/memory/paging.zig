//const pmm = @import("pmm.zig");
const kernel_heap = @import("kernel_heap.zig");
const kernel_common = @import("../kernel_common.zig");
const terminal = @import("../terminal.zig");
const CACHE_DISABLED: u8 = 0b00010000;
const WRITE_THROUGH: u8 = 0b00001000;
const ACCESS_FROM_ALL: u8 = 0b00000100;
const IS_WRITEABLE: u8 = 0b00000010;
const IS_PRESENT: u8 = 0b00000001;
const PAGE_SIZE = 4096;

const ENTRIES_PER_DIRECTORY: usize = 1024;
const ENTRIES_PER_TABLE: usize = 1024;
const PAGE_TABLE_COUNT: usize = 1024;
const PAGE_TABLE_UPPER_BASE: usize = 0xFFC00000;

pub const HIGHER_HALF_ADDRESS = 0xC0000000;
const HIGHER_HALF_INDEX = HIGHER_HALF_ADDRESS / (PAGE_SIZE * ENTRIES_PER_TABLE);

const PageDirectory = *[ENTRIES_PER_DIRECTORY]PageDirectoryEntry;

const PageDirectoryEntry = packed struct {
    flags: u12 = 0,
    address: u20 = 0,
};

const PageTable = *[ENTRIES_PER_TABLE]PageTableEntry;

const PageTableEntry = packed struct {
    flags: u12 = 0,
    address: u20 = 0,
};

var pageDirectoryIdentity: PageDirectory align(PAGE_SIZE) linksection(".multiboot.text") = undefined;
var pageDirectoryEntries: [ENTRIES_PER_DIRECTORY]PageDirectoryEntry align(PAGE_SIZE) linksection(".multiboot.text") = [_]PageDirectoryEntry{.{}} ** ENTRIES_PER_DIRECTORY;
var pageTable0: PageTable align(PAGE_SIZE) linksection(".multiboot.text") = undefined;
var pageTable0Entries: [ENTRIES_PER_TABLE]PageTableEntry align(PAGE_SIZE) linksection(".multiboot.text") = [_]PageTableEntry{.{}} ** ENTRIES_PER_TABLE;

// Place virtual addresses for page tables at the end of the 32-bit address space.
const pageTables: *[PAGE_TABLE_COUNT]PageTable = @ptrFromInt(PAGE_TABLE_UPPER_BASE);
var pageDirectory: *PageDirectory = undefined;

pub export fn setupHigherHalf() linksection(".multiboot.text") void {
    pageDirectoryIdentity = &pageDirectoryEntries;
    pageTable0 = &pageTable0Entries;

    pageDirectoryIdentity[0].address = @truncate(@intFromPtr(pageTable0) >> 12);
    pageDirectoryIdentity[0].flags = IS_PRESENT | IS_WRITEABLE;

    pageDirectoryIdentity[HIGHER_HALF_INDEX].address = pageDirectoryIdentity[0].address;
    pageDirectoryIdentity[HIGHER_HALF_INDEX].flags = pageDirectoryIdentity[0].flags;

    //Recursive mapping setup.
    pageDirectoryIdentity[ENTRIES_PER_DIRECTORY - 1].address = PAGE_TABLE_UPPER_BASE >> 12;
    pageDirectoryIdentity[ENTRIES_PER_DIRECTORY - 1].flags = IS_PRESENT | IS_WRITEABLE;

    //Only map the first 4 MB.
    //pmm.allocate();
    for (0..ENTRIES_PER_TABLE) |table_index| {
        pageTable0[table_index].address = @truncate((table_index * PAGE_SIZE) >> 12);
        pageTable0[table_index].flags = IS_PRESENT | IS_WRITEABLE;
    }

    asm volatile (
        \\mov %[pageDirectory], %eax
        \\mov %eax, %cr3
        \\mov %cr0, %eax
        \\or $0x80010000, %eax
        \\mov %eax, %cr0
        :
        : [pageDirectory] "{ecx}" (pageDirectoryIdentity),
        : .{ .ecx = true, .memory = true });
}

pub fn removeIdentityMapping() void {
    pageDirectory = @ptrCast(&pageTables[PAGE_TABLE_COUNT - 1]);
    // const pageDirectory0Address = pageDirectory.*[0].address;
    // _ = pageDirectory0Address;
    // const pageDirectory0Flags = pageDirectory.*[0].flags;
    // _ = pageDirectory0Flags;
    // pageDirectory.*[0].address = 0;
    // pageDirectory.*[0].flags = 0;
    asm volatile (
        \\mov %cr0, %eax
        \\mov %eax, %cr0
    );
}

pub fn makePageDirectory(flags: u8) !void {
    _ = flags;
    //kernel_common.printString("Initializing Paging...");
    //pageDirectory.entries = @ptrCast(@alignCast(try kernel_heap.kmalloc(@sizeOf(PageDirectoryEntry) * TOTAL_ENTRIES_PER_DIRECTORY)));

    //Only map the first 8 MB.
    //for (0..2) |directory_index| {
    //    var page_table: PageTable = PageTable{};
    //    page_table.entries = @ptrCast(@alignCast(try kernel_heap.kmalloc(@sizeOf(PageTableEntry) * TABLE_ENTRIES_PER_DIRECTORY_ENTRY)));

    //    pageDirectory.entries[directory_index].address = @truncate((@intFromPtr(page_table.entries) & 0xFFFFF000) >> 12);
    //    pageDirectory.entries[directory_index].flags = flags;

    //    for (0..TABLE_ENTRIES_PER_DIRECTORY_ENTRY) |table_index| {
    //        page_table.entries[table_index].address = @truncate((((directory_index * TABLE_ENTRIES_PER_DIRECTORY_ENTRY + table_index) * 0x1000) & 0xFFFFF000) >> 12);
    //        page_table.entries[table_index].flags = flags;
    //    }
    //}

    // Map kernel to higher-half (0xC0000000)
    //var page_table: PageTable = PageTable{};
    //page_table.entries = @ptrCast(@alignCast(try kernel_heap.kmalloc(@sizeOf(PageTableEntry) * TABLE_ENTRIES_PER_DIRECTORY_ENTRY)));
    //pageDirectory.entries[768].address = @truncate((@intFromPtr(page_table.entries) & 0xFFFFF000) >> 12);

    //for (0..1024) |table_index| {
    //    page_table.entries[table_index].address = @truncate(((table_index * 0x1000) & 0xFFFFF000) >> 12);
    //    page_table.entries[table_index].flags = flags;
    //}

    //const virtual_address = 0xc0100000;
    //var page_directory_index: u10 = (virtual_address & 0xFFC00000) >> 22;
    //var page_table_index: u10 = (virtual_address & 0x003FF000) >> 12;
    //var offset: u12 = virtual_address & 0x00000FFF;

    //page_directory_index += 0;
    //page_table_index += 0;
    //offset += 0;

    //kernel_common.printFormat("Directory index: 0x{x}\n", .{page_directory_index});
    //kernel_common.printFormat("Table index: 0x{x}\n", .{page_table_index});

    //const page_table_address = @as(u20, @bitCast(pageDirectory.entries[page_directory_index].address));
    //const page_table_ptr: *PageTable = @ptrFromInt(page_table_address);
    //const page_table_entry = page_table_ptr.entries[page_table_index];

    //const physical_address = (@as(u32, page_table_entry.address) & 0xFFFFF000) + offset;
    //kernel_common.printFormat("Physical address: 0x{x}\n", .{physical_address});

    //return pageDirectory;
}

pub fn getPhysicalAddress(virtual_address: usize) usize {
    const page_directory_index = virtual_address >> 22;
    const page_table_index = (virtual_address & 0x003FF000) >> 12;
    const offset = virtual_address & 0xFFF;

    const page_table_address = @as(usize, @truncate(@as(usize, pageDirectory.*[page_directory_index].address << 12)));
    const page_table: *PageTable = @ptrFromInt(page_table_address);
    const page_table_entry = page_table.*[page_table_index];

    const physical_address = page_table_entry.address + offset;

    return physical_address;
}

//fn free(heap_struct: *const Heap, ptr: *u8) !void {
//    _ = ptr;
//}

fn createPageTable() void {}

fn tableExists(virtual_address: usize) bool {
    _ = virtual_address;
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
