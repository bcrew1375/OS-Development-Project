const boot = @import("../main.zig");

pub export var requests_start_marker: [4]u64 linksection(".limine_requests_start") = .{
    0xf6b8f4b39de7d1ae,
    0xfab91a6940fcb9cf,
    0x785c6ed015d3e316,
    0x181e920a7852b9d9,
};

pub export var hhdm_request: HhdmRequest linksection(".limine_requests") = .{};
pub export var memory_map_request: MemoryMapRequest linksection(".limine_requests") = .{};
pub export var module_request: ModuleRequest linksection(".limine_requests") = .{};

pub export var requests_end_marker: [2]u64 linksection(".limine_requests_end") = .{
    0xadc0e0531bb10d03,
    0x9572709f31764c62,
};

pub export fn _start() callconv(.c) noreturn {
    boot.kernelSetup();
}

pub const HhdmRequest = extern struct {
    id: [2]u64 = .{ 0x48dcf1cb8ad2b852, 0x63984e959a98244b },
    revision: u64 = 0,
    response: ?*HhdmResponse = null,
};

pub const HhdmResponse = extern struct {
    revision: u64,
    offset: u64,
};

pub const MemoryMapRequest = extern struct {
    id: [2]u64 = .{ 0x67cf3d9d378a806f, 0xe304acdfc50c3c62 },
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
    id: [2]u64 = .{ 0x3e7e279702be32af, 0xca1c4f3bd1280cee },
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

pub fn getHhdmOffset() usize {
    const response = hhdm_request.response orelse return 0;
    return @intCast(response.offset);
}
