const kernel_heap = @import("./kernel_heap.zig");
const kernel_common = @import("../kernel_common.zig");
const PAGING_CACHE_DISABLED: u8 = 0b00010000;
const PAGING_WRITE_THROUGH: u8 = 0b00001000;
const PAGING_ACCESS_FROM_ALL: u8 = 0b00000100;
const PAGING_IS_WRITEABLE: u8 = 0b00000010;
const PAGING_IS_PRESENT: u8 = 0b00000001;
const PAGE_SIZE = 4096;

const TOTAL_ENTRIES_PER_DIRECTORY: usize = 1024;
const TABLE_ENTRIES_PER_DIRECTORY_ENTRY: usize = 1024;

pub const PageTable = struct {
    entries: *[TABLE_ENTRIES_PER_DIRECTORY_ENTRY]PageTableEntry = undefined,
};

pub const PageTableEntry = packed struct {
    flags: u12 = 0,
    address: u20 = 0,
};

pub const PageDirectory = struct {
    entries: *[TOTAL_ENTRIES_PER_DIRECTORY]PageDirectoryEntry = undefined,
};

pub const PageDirectoryEntry = packed struct {
    flags: u12 = 0,
    address: u20 = 0,
};

var pageDirectory: PageDirectory = undefined;

pub fn makePageDirectory(flags: u8) !void {
    kernel_common.printString("Initializing Paging...");
    pageDirectory.entries = @ptrCast(@alignCast(try kernel_heap.kmalloc(@sizeOf(PageDirectoryEntry) * TOTAL_ENTRIES_PER_DIRECTORY)));

    //Only map the first 8 MB.
    for (0..2) |directory_index| {
        var page_table: PageTable = PageTable{};
        page_table.entries = @ptrCast(@alignCast(try kernel_heap.kmalloc(@sizeOf(PageTableEntry) * TABLE_ENTRIES_PER_DIRECTORY_ENTRY)));

        pageDirectory.entries[directory_index].address = @truncate((@intFromPtr(page_table.entries) & 0xFFFFF000) >> 12);
        pageDirectory.entries[directory_index].flags = flags;

        for (0..TABLE_ENTRIES_PER_DIRECTORY_ENTRY) |table_index| {
            page_table.entries[table_index].address = @truncate((((directory_index * TABLE_ENTRIES_PER_DIRECTORY_ENTRY + table_index) * 0x1000) & 0xFFFFF000) >> 12);
            page_table.entries[table_index].flags = flags;
        }
    }

    // Map kernel to higher-half (0xC0000000)
    var page_table: PageTable = PageTable{};
    page_table.entries = @ptrCast(@alignCast(try kernel_heap.kmalloc(@sizeOf(PageTableEntry) * TABLE_ENTRIES_PER_DIRECTORY_ENTRY)));
    pageDirectory.entries[768].address = @truncate((@intFromPtr(page_table.entries) & 0xFFFFF000) >> 12);

    for (0..1024) |table_index| {
        page_table.entries[table_index].address = @truncate(((table_index * 0x1000) & 0xFFFFF000) >> 12);
        page_table.entries[table_index].flags = flags;
    }

    const virtual_address = 0xc0100000;
    const page_directory_index = (virtual_address & 0xFFC00000) >> 22;
    const page_table_index = (virtual_address & 0x003FF000) >> 12;
    const offset = virtual_address & 0xFFF;

    kernel_common.printFormat("Directory index: 0x{x}\n", .{page_directory_index});
    kernel_common.printFormat("Table index: 0x{x}\n", .{page_table_index});

    const page_table_address = @as(u32, pageDirectory.entries[page_directory_index].address) & 0xFFFFF000;
    const page_table_ptr: *PageTable = @ptrFromInt(page_table_address);
    const page_table_entry = page_table_ptr.entries[page_table_index];

    const physical_address = (@as(u32, page_table_entry.address) & 0xFFFFF000) + offset;
    kernel_common.printFormat("Physical address: 0x{x}\n", .{physical_address});

    asm volatile (
        \\pusha
        \\mov %[pageDirectory], %eax
        \\mov %eax, %cr3
        \\mov %cr0, %eax
        \\or $0x80000000, %eax
        \\mov %eax, %cr0
        \\popa
        //\\mov $0xC0100000, %ebx
        //\\jmp *%ebx
        :
        : [pageDirectory] "{ebx}" (pageDirectory.entries),
        : .{ .ebx = true, .memory = true });

    kernel_common.printStringColor("done.\n", kernel_common.COLOR.GREEN);
    //return pageDirectory;
}

pub fn getPhysicalAddress(virtual_address: usize) usize {
    const page_directory_index = (virtual_address & 0xFFC00000) >> 22;
    const page_table_index = (virtual_address & 0x003FF000) >> 12;
    const offset = virtual_address & 0xFFF;

    const page_table_address = pageDirectory.entries[page_directory_index].address;
    const page_table: *PageTable = @ptrFromInt(page_table_address);
    const page_table_entry = page_table.entries[page_table_index];

    const physical_address = page_table_entry.address + offset;

    return physical_address;
}
