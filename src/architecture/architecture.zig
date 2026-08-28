const builtin = @import("builtin");

pub const impl = if (builtin.is_test)
    @import("mock/arch.zig")
else switch (builtin.cpu.arch) {
    .x86 => @import("x86/32/arch.zig"),
    .x86_64 => @import("x86/64/arch.zig"),
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
    AddressSpaceRootAllocationFailed,
};

pub const AddressSpaceRoot = struct {
    value: usize,
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
    TEMPORARY,
    PERSISTENT,
    KERNEL_READ_ONLY,
    KERNEL_WRITABLE,
    BOOTLOADER_DATA,
    DEVICE_MEMORY,
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

pub const BootModule = struct {
    physical_start: usize,
    physical_end: usize,
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
    execute: bool = false,
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
            getBootModuleCount: fn () usize,
            getBootModule: fn (index: usize) ?BootModule,
        });

        validateInterface(T.cpu, struct {
            unrecoverableHalt: fn () noreturn,
            enterUserMode: fn (entry_point: usize, stack_top: usize, argument0: usize) noreturn,
        });

        validateInterface(T.mmu, struct {
            createAddressSpaceRoot: fn () MmuError!AddressSpaceRoot,
            switchAddressSpaceRoot: fn (root: AddressSpaceRoot) void,
            getPhysicalAddressInAddressSpace: fn (root: AddressSpaceRoot, virtualAddress: usize) ?usize,
            getPhysicalAddress: fn (virtualAddress: usize) ?usize,
            isTablePresentInAddressSpace: fn (root: AddressSpaceRoot, virtualAddress: usize) bool,
            isTablePresent: fn (virtualAddress: usize) bool,
            getMemoryMap: fn () *MemoryMap,
            mapPageInAddressSpace: fn (root: AddressSpaceRoot, virtualAddress: usize, physicalAddress: usize, flags: PageProtection) MmuError!void,
            mapPage: fn (virtualAddress: usize, physicalAddress: usize, flags: PageProtection) MmuError!void,
            mapTableInAddressSpace: fn (root: AddressSpaceRoot, virtualAddress: usize, physicalAddress: usize, flags: PageProtection) MmuError!void,
            mapTable: fn (virtualAddress: usize, physicalAddress: usize, flags: PageProtection) MmuError!void,
            unmapPage: fn (virtualAddress: usize) void,
            getMaxAvailableAddress: fn () u64,
            getDirectMapVirtualAddress: fn () u64,
            getDirectMapMaxSize: fn () u64,
            getKernelVirtualAddressStart: fn () u64,
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
