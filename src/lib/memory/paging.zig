const kernel_heap = @import("./kernel_heap.zig");
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

pub const HIGHER_HALF_ADDRESS = 0xC0000000;
const HIGHER_HALF_INDEX = HIGHER_HALF_ADDRESS / (PAGE_SIZE * ENTRIES_PER_TABLE);

const PageDirectory = struct {
    entries: *[ENTRIES_PER_DIRECTORY]PageDirectoryEntry = undefined,
};

const PageDirectoryEntry = packed struct {
    flags: u12 = 0,
    address: u20 = 0,
};

const PageTable = struct {
    entries: *[ENTRIES_PER_TABLE]PageTableEntry = undefined,
};

const PageTableEntry = packed struct {
    flags: u12 = 0,
    address: u20 = 0,
};

var pageDirectory: PageDirectory linksection(".multiboot.text") = PageDirectory{};
var pageDirectoryEntries: [ENTRIES_PER_DIRECTORY]PageDirectoryEntry align(PAGE_SIZE) linksection(".multiboot.text") = [_]PageDirectoryEntry{.{}} ** ENTRIES_PER_DIRECTORY;
var pageTableIdentity: PageTable linksection(".multiboot.text") = PageTable{};
var pageTableIdentityEntries: [ENTRIES_PER_TABLE]PageTableEntry align(PAGE_SIZE) linksection(".multiboot.text") = [_]PageTableEntry{.{}} ** ENTRIES_PER_TABLE;

pub fn enablePaging() linksection(".multiboot.text") void {
    pageDirectory.entries = &pageDirectoryEntries;
    pageTableIdentity.entries = &pageTableIdentityEntries;

    //Only map the first 4 MB.
    pageDirectory.entries[0].address = @truncate(@intFromPtr(pageTableIdentity.entries) >> 12);
    pageDirectory.entries[0].flags = IS_PRESENT | IS_WRITEABLE;

    pageDirectory.entries[HIGHER_HALF_INDEX].address = pageDirectory.entries[0].address;
    pageDirectory.entries[HIGHER_HALF_INDEX].flags = pageDirectory.entries[0].flags;

    for (0..ENTRIES_PER_TABLE) |table_index| {
        pageTableIdentity.entries[table_index].address = @truncate((table_index * PAGE_SIZE) >> 12);
        pageTableIdentity.entries[table_index].flags = IS_PRESENT | IS_WRITEABLE;
    }

    asm volatile (
        \\mov %[pageDirectory], %eax
        \\mov %eax, %cr3
        \\mov %cr0, %eax
        \\or $0x80010000, %eax
        \\mov %eax, %cr0
        :
        : [pageDirectory] "{ecx}" (pageDirectory.entries),
        : .{ .ecx = true, .memory = true });
}

pub fn removeIdentityEntry() void {
    asm volatile (
        \\add $0xC0000000, %esp
    );
    pageDirectory.entries[0].address = 0;
    pageDirectory.entries[0].flags = 0;
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
    _ = virtual_address;
    //const page_directory_index = (virtual_address & 0xFFC00000) >> 22;
    //const page_table_index = (virtual_address & 0x003FF000) >> 12;
    //const offset = virtual_address & 0xFFF;

    //const page_table_address = pageDirectory.entries[page_directory_index].address;
    //const page_table: *PageTable = @ptrFromInt(page_table_address);
    //const page_table_entry = page_table.entries[page_table_index];

    //const physical_address = page_table_entry.address + offset;

    //return physical_address;
    return 0;
}
