const kernel_heap = @import("./kernel_heap.zig");
const kernel_common = @import("../kernel_common.zig");
const PAGING_CACHE_DISABLED: u8 = 0b00010000;
const PAGING_WRITE_THROUGH: u8 = 0b00001000;
const PAGING_ACCESS_FROM_ALL: u8 = 0b00000100;
const PAGING_IS_WRITEABLE: u8 = 0b00000010;
const PAGING_IS_PRESENT: u8 = 0b00000001;

const TOTAL_ENTRIES_PER_DIRECTORY: u16 = 1024;
const TOTAL_ENTRIES_PER_TABLE: u16 = 1024;

// Paging chunk is 4 GB total.
const PageDirectory = struct {
    table_entries: [TOTAL_ENTRIES_PER_DIRECTORY]*u32,
};

pub fn makePageDirectoryEntry(flags: u8) !*PageDirectory {
    const page_directory: *PageDirectory = @ptrCast(@alignCast(try kernel_heap.kmalloc(@sizeOf(u32) * TOTAL_ENTRIES_PER_DIRECTORY)));
    for (0..TOTAL_ENTRIES_PER_DIRECTORY) |entry| {
        page_directory.table_entries[entry] = @ptrCast(@alignCast(try kernel_heap.kmalloc(@sizeOf(u32) * TOTAL_ENTRIES_PER_TABLE)));
    }
    _ = flags;
    asm volatile (
        \\mov %eax, (%ebx)
        \\mov %cr3, %eax
        \\mov %eax, %cr0
        \\or %eax, 0x80000001
        \\mov %cr0, %eax
        :
        : [page_directory] "{ebx}" (&page_directory),
        : .{ .ebx = true, .memory = true });
    return page_directory;
}
