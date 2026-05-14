pub const PAGE_SIZE = 4096;

pub const KERNEL_CORE_VIRTUAL_ADDRESS = 0xC0000000;
pub const KERNEL_HEAP_VIRTUAL_ADDRESS = 0xD0000000;

pub const ENTRIES_PER_DIRECTORY: usize = 1024;
pub const ENTRIES_PER_TABLE: usize = 1024;

pub const PAGE_TABLES_COUNT: usize = 1024;
pub const PAGE_TABLES_BASE = 0xFFC00000;

pub const HIGHER_HALF_INDEX = KERNEL_CORE_VIRTUAL_ADDRESS / (PAGE_SIZE * ENTRIES_PER_TABLE);

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

pub const PageDirectory = *[ENTRIES_PER_DIRECTORY]PageEntry;
pub const PageTable = *[ENTRIES_PER_TABLE]PageEntry;
