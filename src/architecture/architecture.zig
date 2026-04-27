const builtin = @import("builtin");

pub const impl = if (builtin.is_test)
    @import("mock/arch.zig")
else switch (builtin.cpu.arch) {
    //.x86_64 => @import("x86_64/impl.zig"),
    .x86 => @import("x86/arch.zig"),
    //.aarch64 => @import("aarch64/impl.zig"),
    //.riscv64 => @import("riscv64/impl.zig"),
    else => @compileError("unsupported architecture: " ++
        @tagName(builtin.cpu.arch)),
};

pub const early_allocator = impl.early_allocator;
pub const boot = impl.boot;
pub const cpu = impl.cpu;
pub const interrupts = impl.interrupts;
pub const mmu = impl.mmu;
pub const platform = impl.platform;

pub const TextColor = enum(u8) {
    BLACK,
    BLUE,
    GREEN,
    CYAN,
    RED,
    MAGENTA,
    BROWN,
    LIGHT_GRAY,
    DARK_GRAY,
    LIGHT_BLUE,
    LIGHT_GREEN,
    LIGHT_CYAN,
    LIGHT_RED,
    LIGHT_MAGENTA,
    YELLOW,
    WHITE,
};

pub const MAX_MEMORY_MAP_ENTRIES = 128;
pub const MAX_EARLY_RESERVATIONS = 128;

pub const MmuError = error{
    MemoryMapReadError,
};

pub const MemoryMap = struct {
    entries: *[MAX_MEMORY_MAP_ENTRIES]MemoryMapEntry = undefined,
    length: usize = 0,
    available_regions: usize = 0,
};

pub const MemoryMapEntry = struct {
    address: u64 = undefined,
    size: u64 = undefined,
    region_type: MemoryMapEntryType = MemoryMapEntryType.RESERVED,
};

pub const MemoryMapEntryType = enum(u8) {
    AVAILABLE,
    RESERVED,
    RECLAIMABLE,
    BAD,
};

pub const ReservedMapEntryType = enum {
    TEMPORARY,
    PERSISTENT,
};

pub const ReservedMapEntry = struct {
    address: usize,
    size: usize,
    entry_type: ReservedMapEntryType,
};

pub const ReservedMap = struct {
    entries: [MAX_EARLY_RESERVATIONS]ReservedMapEntry = undefined,
    length: usize = 0,
};

pub const EarlyAllocError = error{
    OutOfReservations,
    OutOfSpace,
    InvalidSize,
    InvalidAlignment,
    InvalidMemoryMap,
};

pub fn validateImpl(comptime T: type) void {
    comptime {
        //early_allocator
        assertFn(T.early_allocator, "initialize", fn () EarlyAllocError!void);
        assertFn(T.early_allocator, "allocate", fn (neededSize: usize, alignment: usize, entryType: ReservedMapEntryType) EarlyAllocError!*allowzero anyopaque);
        assertFn(T.early_allocator, "reserve", fn (address: usize, size: usize, entry_type: ReservedMapEntryType) EarlyAllocError!void);
        assertFn(T.early_allocator, "getReservedMap", fn () *ReservedMap);

        // boot
        assertFn(T.boot, "finishBoot", fn () void);

        // cpu
        assertFn(T.cpu, "unrecoverableHalt", fn () noreturn);

        // mmu
        assertFn(T.mmu, "removeIdentityMapping", fn () void);
        assertFn(T.mmu, "getPhysicalAddress", fn (virtualAddress: usize) ?usize);
        assertFn(T.mmu, "getMemoryMap", fn () *MemoryMap);
        assertFn(T.mmu, "mapPage", fn (virtualAddress: usize, physicalAddress: usize) void);
        assertFn(T.mmu, "unmapPage", fn (virtualAddress: usize) void);
        assertFn(T.mmu, "getMaxAvailableAddress", fn () u64);

        // interrupts
        assertFn(T.interrupts, "initialize", fn () void);
        assertFn(T.interrupts, "set", fn (interruptVector: usize, address: usize, typeAttribute: usize) void);
        assertFn(T.interrupts, "enableInterrupts", fn () void);
        assertFn(T.interrupts, "disableInterrupts", fn () void);
        assertFn(T.interrupts, "acknowledgeInterrupt", fn (vector: usize) void);

        // platform
        assertFn(T.platform, "initializeTimer", fn (frequency: usize) void);
        assertFn(T.platform, "initializeConsole", fn () void);
        assertFn(T.platform, "setColor", fn (color: TextColor) void);
        if (!@hasDecl(T.platform, "writer"))
            @compileError(@typeName(T.platform) ++ " is missing 'writer' instance");
    }
}

fn assertFn(comptime T: type, comptime functionName: []const u8, comptime signature: type) void {
    if (!@hasDecl(T, functionName))
        @compileError(@typeName(T) ++ " is missing '" ++ functionName ++ "'");
    if (@TypeOf(@field(T, functionName)) != signature)
        @compileError(@typeName(T) ++ "." ++ functionName ++ " has type: " ++ @typeName(@TypeOf(@field(T, functionName))) ++ ", expected type: " ++ @typeName(signature));
}
