const early_allocator_impl = @import("early_allocator/main.zig");
const boot_impl = @import("boot/main.zig");
const cpu_impl = @import("cpu/main.zig");
const interrupts_impl = @import("interrupts/main.zig");
const mmu_impl = @import("mmu/main.zig");
const platform_impl = @import("platform/main.zig");

const validateImpl = @import("../architecture.zig").validateImpl;

comptime {
    validateImpl(@This());
}

pub const early_allocator = struct {
    pub const initialize = early_allocator_impl.initialize;
    pub const allocate = early_allocator_impl.allocate;
    pub const reserve = early_allocator_impl.reserve;
    pub const getReservedMap = early_allocator_impl.getReservedMap;
};

pub const boot = struct {
    pub const finishBoot = boot_impl.finishBoot;
};

pub const cpu = struct {
    pub const unrecoverableHalt = cpu_impl.unrecoverableHalt;
};

pub const interrupts = struct {
    pub const initialize = interrupts_impl.idt.initialize;
    pub const set = interrupts_impl.idt.set;
    pub const enableInterrupts = interrupts_impl.enableInterrupts;
    pub const disableInterrupts = interrupts_impl.disableInterrupts;
    pub const acknowledgeInterrupt = interrupts_impl.acknowledgeInterrupt;
};

pub const mmu = struct {
    pub const getPhysicalAddress = mmu_impl.getPhysicalAddress;
    pub const getMemoryMap = mmu_impl.getMemoryMap;
    pub const mapPage = mmu_impl.mapPage;
    pub const mapTable = mmu_impl.mapTable;
    pub const unmapPage = mmu_impl.unmapPage;
    pub const getMaxAvailableAddress = mmu_impl.getMaxAvailableAddress;
    pub const getDirectMapVirtualAddress = mmu_impl.getDirectMapVirtualAddress;
    pub const getDirectMapMaxSize = mmu_impl.getDirectMapMaxSize;
    pub const getKernelHeapVirtualAddress = mmu_impl.getKernelHeapVirtualAddress;
    pub const getKernelHeapSize = mmu_impl.getKernelHeapSize;
};

pub const platform = struct {
    pub const initializeTimer = platform_impl.time.initializeTimer;
    pub const initializeConsole = platform_impl.io.serial.initialize;
    pub const setColor = platform_impl.console.setColor;
    pub const writer = platform_impl.console.writer;
};
