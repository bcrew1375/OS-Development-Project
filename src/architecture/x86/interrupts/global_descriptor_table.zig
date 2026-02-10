const GlobalDescriptorTable = packed struct {
    null_1: u32 = 0,
    null_2: u32 = 0,

    code_limit: u16 = 0xffff,
    code_base_low: u24 = 0,
    code_access: u8 = 0x9a,
    code_flags: u8 = 0b11001111,
    code_base_high: u8 = 0,

    data_limit: u16 = 0xffff,
    data_base_low: u24 = 0,
    data_access: u8 = 0x92,
    data_flags: u8 = 0b11001111,
    data_base_high: u8 = 0,

    tss_limit: u16 = undefined,
    tss_base_low: u24 = undefined,
    tss_access: u8 = 0x89,
    tss_flags: u8 = 0x00,
    tss_high: u8 = undefined,
};

const GlobalDescriptorTableRegister = packed struct {
    size: u16 = undefined,
    address: u32 = undefined,
};

var tss: [104]u8 = undefined;
var gdt = GlobalDescriptorTable{};
var gdtr = GlobalDescriptorTableRegister{};

pub const CODE_SELECTOR = @offsetOf(GlobalDescriptorTable, "code_limit");

pub fn initialize() void {
    const tss_address = @intFromPtr(&tss);

    gdt.tss_limit = tss.len - 1;
    gdt.tss_base_low = @truncate(tss_address & 0x00FFFFFF);
    gdt.tss_high = @truncate(tss_address >> 24);

    gdtr.address = @intFromPtr(&gdt);
    gdtr.size = @sizeOf(GlobalDescriptorTable) - 1;

    asm volatile (
        \\lgdt (%ecx)
        \\
        \\mov $0x10, %ax
        \\mov %ax, %ds
        \\mov %ax, %es
        \\mov %ax, %fs
        \\mov %ax, %ss
        :
        : [gdtr] "{ecx}" (&gdtr),
        : .{ .ecx = true, .memory = true });
}
