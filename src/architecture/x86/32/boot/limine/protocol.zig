const LimineRequestId = [4]u64;

const LIMINE_COMMON_REQUEST_ID_PREFIX = .{
    0xc7b1dd30df4c8b88,
    0x0a82e883a194f07b,
};

const HHDM_REQUEST_ID: LimineRequestId = LIMINE_COMMON_REQUEST_ID_PREFIX ++ .{
    0x48dcf1cb8ad2b852,
    0x63984e959a98244b,
};

const MEMORY_MAP_REQUEST_ID: LimineRequestId = LIMINE_COMMON_REQUEST_ID_PREFIX ++ .{
    0x67cf3d9d378a806f,
    0xe304acdfc50c3c62,
};

const MODULE_REQUEST_ID: LimineRequestId = LIMINE_COMMON_REQUEST_ID_PREFIX ++ .{
    0x3e7e279702be32af,
    0xca1c4f3bd1280cee,
};

const FRAMEBUFFER_REQUEST_ID: LimineRequestId = LIMINE_COMMON_REQUEST_ID_PREFIX ++ .{
    0x9d5827dcd881dd75,
    0xa3148604f6fab11b,
};

pub const HhdmRequest = extern struct {
    id: LimineRequestId = HHDM_REQUEST_ID,
    revision: u64 = 0,
    response: ?*HhdmResponse = null,
};

pub const HhdmResponse = extern struct {
    revision: u64,
    offset: u64,
};

pub const MemoryMapRequest = extern struct {
    id: LimineRequestId = MEMORY_MAP_REQUEST_ID,
    revision: u64 = 0,
    response: ?*MemoryMapResponse = null,
};

pub const MemoryMapResponse = extern struct {
    revision: u64,
    entry_count: u64,
    entries: [*]const *const MemoryMapEntry,
};

pub const MemoryMapEntry = extern struct {
    base: u64,
    length: u64,
    entry_type: MemoryMapEntryType,
};

pub const MemoryMapEntryType = enum(u64) {
    USABLE = 0,
    RESERVED = 1,
    ACPI_RECLAIMABLE = 2,
    ACPI_NVS = 3,
    BAD_MEMORY = 4,
    BOOTLOADER_RECLAIMABLE = 5,
    KERNEL_AND_MODULES = 6,
    FRAMEBUFFER = 7,
    _,
};

pub const ModuleRequest = extern struct {
    id: LimineRequestId = MODULE_REQUEST_ID,
    revision: u64 = 0,
    response: ?*ModuleResponse = null,
    internal_module_count: u64 = 0,
    internal_modules: ?[*]const *const File = null,
};

pub const ModuleResponse = extern struct {
    revision: u64,
    module_count: u64,
    modules: [*]const *const File,
};

pub const FramebufferRequest = extern struct {
    id: LimineRequestId = FRAMEBUFFER_REQUEST_ID,
    revision: u64 = 0,
    response: ?*FramebufferResponse = null,
};

pub const FramebufferResponse = extern struct {
    revision: u64,
    framebuffer_count: u64,
    framebuffers: [*]const *const Framebuffer,
};

pub const VideoMode = extern struct {
    pitch: u64,
    width: u64,
    height: u64,
    bits_per_pixel: u16,
    memory_model: u8,
    red_mask_size: u8,
    red_mask_shift: u8,
    green_mask_size: u8,
    green_mask_shift: u8,
    blue_mask_size: u8,
    blue_mask_shift: u8,
};

pub const Framebuffer = extern struct {
    address: *allowzero anyopaque,
    width: u64,
    height: u64,
    pitch: u64,
    bits_per_pixel: u16,
    memory_model: u8,
    red_mask_size: u8,
    red_mask_shift: u8,
    green_mask_size: u8,
    green_mask_shift: u8,
    blue_mask_size: u8,
    blue_mask_shift: u8,
    unused: [7]u8,
    edid_size: u64,
    edid: ?[*]const u8,
    mode_count: u64,
    modes: ?[*]const *const VideoMode,
};

pub const File = extern struct {
    revision: u64,
    address: *const anyopaque,
    size: u64,
    path: [*:0]const u8,
    cmdline: [*:0]const u8,
    media_type: u32,
    unused: u32,
    tftp_ip: u32,
    tftp_port: u32,
    partition_index: u32,
    mbr_disk_id: u32,
    gpt_disk_uuid: [16]u8,
    gpt_part_uuid: [16]u8,
    part_uuid: [16]u8,
};
