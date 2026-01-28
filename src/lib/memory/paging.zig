const kernel_heap = @import("../kernel_heap.zig");
const PAGING_CACHE_DISABLED: u8 = 0b00010000;
const PAGING_WRITE_THROUGH: u8 = 0b00001000;
const PAGING_ACCESS_FROM_ALL: u8 = 0b00000100;
const PAGING_IS_WRITEABLE: u8 = 0b00000010;
const PAGING_IS_PRESENT: u8 = 0b00000001;

const TOTAL_ENTRIES_PER_TABLE: u8 = 1024;

const PageDirectoryEntry = struct {
    entry: u32,
};

fn makePageDirectoryEntry(entry: u32) *PageDirectoryEntry {
    var directory_entry: *u32 = kernel_heap.kmalloc(@sizeOf(u32) * TOTAL_ENTRIES_PER_TABLE);
}
