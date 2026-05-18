pub const PAGE_SIZE = 4096;

pub const ENTRIES_PER_DIRECTORY: usize = 1024;
pub const ENTRIES_PER_TABLE: usize = 1024;

pub const PAGE_TABLE_REGION_SIZE = PAGE_SIZE * ENTRIES_PER_TABLE;

pub const DIRECT_MAP_VIRTUAL_ADDRESS = 0xC0000000;
pub const DIRECT_MAP_SIZE = 768 * 1024 * 1024;

pub const KERNEL_HEAP_VIRTUAL_ADDRESS = 0xF0000000;
pub const KERNEL_HEAP_SIZE = 256 * 1024 * 1024;

pub const HIGHER_HALF_INDEX = DIRECT_MAP_VIRTUAL_ADDRESS / (PAGE_SIZE * ENTRIES_PER_TABLE);

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
