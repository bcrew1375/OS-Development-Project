pub const BOOT_INFO_MAGIC: u32 = 0xB007_1F00;
pub const BOOT_INFO_VERSION: u32 = 1;

pub const BootInfo = extern struct {
    magic: u32,
    version: u32,
    module_count: u32,
    modules_address: u32,
};

pub const BootModuleInfo = extern struct {
    physical_start: u64,
    physical_end: u64,
};
