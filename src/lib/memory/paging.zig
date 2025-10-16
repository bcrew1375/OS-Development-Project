const kernel_heap = @import("./kernel_heap.zig");
const kernel_common = @import("../kernel_common.zig");
const PAGING_CACHE_DISABLED: u8 = 0b00010000;
const PAGING_WRITE_THROUGH: u8 = 0b00001000;
const PAGING_ACCESS_FROM_ALL: u8 = 0b00000100;
const PAGING_IS_WRITEABLE: u8 = 0b00000010;
const PAGING_IS_PRESENT: u8 = 0b00000001;

const TOTAL_ENTRIES_PER_DIRECTORY: u16 = 8;
const TABLE_ENTRIES_PER_DIRECTORY_ENTRY: u16 = 1024;

// Max number of entries = 1024.
pub const PageTable = struct {
    entries: *[TABLE_ENTRIES_PER_DIRECTORY_ENTRY]PageTableEntry = undefined,
};

pub const PageTableEntry = packed struct {
    flags: u12 = 0,
    address: u20 = 0,
};

// Max number of entries = 1024.
pub const PageDirectory = struct {
    entries: *[TOTAL_ENTRIES_PER_DIRECTORY]PageDirectoryEntry = undefined,
};

pub const PageDirectoryEntry = packed struct {
    flags: u12 = 0,
    address: u20 = 0,
};

pub fn makePageDirectory(flags: u8) !PageDirectory {
    kernel_common.printString("Initializing Paging...");
    var page_directory: PageDirectory = PageDirectory{};
    page_directory.entries = @ptrCast(@alignCast(try kernel_heap.kmalloc(@sizeOf(PageDirectoryEntry) * TOTAL_ENTRIES_PER_DIRECTORY)));

    for (0..TOTAL_ENTRIES_PER_DIRECTORY) |directory_index| {
        var page_table: PageTable = PageTable{};
        page_table.entries = @ptrCast(@alignCast(try kernel_heap.kmalloc(@sizeOf(PageTableEntry) * TABLE_ENTRIES_PER_DIRECTORY_ENTRY)));

        page_directory.entries[directory_index].address = @truncate((@intFromPtr(page_table.entries) & 0xFFFFF000) >> 12);
        page_directory.entries[directory_index].flags = flags;

        for (0..TABLE_ENTRIES_PER_DIRECTORY_ENTRY) |table_index| {
            page_table.entries[table_index].address = @truncate((((directory_index * TABLE_ENTRIES_PER_DIRECTORY_ENTRY + table_index) * 0x1000) & 0xFFFFF000) >> 12);
            page_table.entries[table_index].flags = flags;
        }
    }

    kernel_common.printFormat("{d}", .{@intFromPtr(page_directory.entries)});
    asm volatile (
        \\pusha
        \\mov %[page_directory], %eax
        \\mov %eax, %cr3
        \\mov %cr0, %eax
        \\or $0x80000000, %eax
        \\mov %eax, %cr0
        \\popa
        :
        : [page_directory] "{ebx}" (page_directory.entries),
        : .{ .ebx = true, .memory = true });

    kernel_common.printStringColor("done.\n", kernel_common.COLOR.GREEN);
    return page_directory;
}
