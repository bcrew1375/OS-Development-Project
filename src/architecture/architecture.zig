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

comptime {
    validateImpl(impl);
}

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
    MappingError,
    PageTableNotPresent,
};

pub const MemoryMap = struct {
    entries: [MAX_MEMORY_MAP_ENTRIES]MemoryMapEntry = undefined,
    length: usize = 0,
    available_regions: usize = 0,
};

pub const MemoryMapEntry = struct {
    address: u64 = undefined,
    size: u64 = undefined,
    region_type: MemoryMapRegionType = MemoryMapRegionType.RESERVED,
};

pub const MemoryMapRegionType = enum(u8) {
    AVAILABLE,
    RESERVED,
    RECLAIMABLE,
    BAD,
};

pub const ReservedMapRegionType = enum {
    TEMPORARY, // Can be reclaimed once the full VM/Slab allocator is up
    PERSISTENT, // Kernel structures that live for the lifetime of the OS
    KERNEL_CODE,
    BOOTLOADER_DATA,
};

pub const ReservedMapEntry = struct {
    address: usize,
    size: usize,
    region_type: ReservedMapRegionType,
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

pub const PageProtection = struct {
    write: bool = false,
    user: bool = false,
    execute: bool = true,
    global: bool = false,
};

pub const FaultInfo = struct {
    address: usize,
    present: bool,
    write: bool,
    user: bool,
    instruction_fetch: bool,
};

pub var earlyAllocatorActive = true;

pub fn validateImpl(comptime T: type) void {
    comptime {
        validateInterface(T.early_allocator, struct {
            initialize: fn () EarlyAllocError!void,
            allocate: fn (needed_size: usize, alignment: usize, region_type: ReservedMapRegionType) EarlyAllocError!*allowzero anyopaque,
            reserve: fn (address: usize, size: usize, region_type: ReservedMapRegionType) EarlyAllocError!void,
            getReservedMap: fn () *ReservedMap,
        });

        validateInterface(T.boot, struct {
            finishBoot: fn () void,
        });

        validateInterface(T.cpu, struct {
            unrecoverableHalt: fn () noreturn,
        });

        validateInterface(T.mmu, struct {
            getPhysicalAddress: fn (virtualAddress: usize) ?usize,
            isTablePresent: fn (virtualAddress: usize) bool,
            getMemoryMap: fn () *MemoryMap,
            mapPage: fn (virtualAddress: usize, physicalAddress: usize, flags: PageProtection) MmuError!void,
            mapTable: fn (virtualAddress: usize, physicalAddress: usize) MmuError!void,
            unmapPage: fn (virtualAddress: usize) void,
            getMaxAvailableAddress: fn () u64,
            getDirectMapVirtualAddress: fn () u64,
            getDirectMapMaxSize: fn () u64,
            getKernelHeapVirtualAddress: fn () u64,
            getKernelHeapSize: fn () u64,
            getPageSize: fn () usize,
            getPageTableRegionSize: fn () usize,
        });

        validateInterface(T.interrupts, struct {
            initialize: fn () void,
            set: fn (interruptVector: usize, address: usize, typeAttribute: usize) void,
            enableInterrupts: fn () void,
            disableInterrupts: fn () void,
            acknowledgeInterrupt: fn (vector: usize) void,
        });

        validateInterface(T.platform, struct {
            initializeTimer: fn (frequency: usize) void,
            initializeConsole: fn () void,
            setColor: fn (color: TextColor) void,
        });

        if (!@hasDecl(T.platform, "writer")) {
            @compileError(@typeName(T.platform) ++ " is missing 'writer' instance");
        }
    }
}

fn validateInterface(comptime Impl: type, comptime Interface: type) void {
    const info = @typeInfo(Interface).@"struct";
    inline for (info.fields) |field| {
        if (!@hasDecl(Impl, field.name)) {
            @compileError(@typeName(Impl) ++ " is missing declaration '" ++ field.name ++ "'");
        }
        const ActualType = @TypeOf(@field(Impl, field.name));
        if (ActualType != field.type) {
            @compileError(@typeName(Impl) ++ "." ++ field.name ++ " has type: " ++ @typeName(ActualType) ++ ", expected: " ++ @typeName(field.type));
        }
    }
}
