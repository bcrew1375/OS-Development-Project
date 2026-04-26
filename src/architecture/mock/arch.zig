const arch = @import("arch");

const boot_impl = @import("boot/main.zig");
const cpu_impl = @import("cpu/main.zig");
const interrupts_impl = @import("interrupts/main.zig");
const mmu_impl = @import("mmu/main.zig");
const platform_impl = @import("platform/main.zig");

const validateImpl = @import("arch").validateImpl;

comptime {
    validateImpl(@This());
}

pub const boot = struct {
    pub const allocate = boot_impl.allocate;
    pub const finishBoot = boot_impl.finishBoot;
};

pub const cpu = struct {
    pub const unrecoverableHalt = cpu_impl.unrecoverableHalt;
};

pub const interrupts = struct {
    pub const initialize = interrupts_impl.initialize;
    pub const set = interrupts_impl.set;
    pub const enableInterrupts = interrupts_impl.enableInterrupts;
    pub const disableInterrupts = interrupts_impl.disableInterrupts;
    pub const acknowledgeInterrupt = interrupts_impl.acknowledgeInterrupt;
};

pub const mmu = struct {
    pub const removeIdentityMapping = mmu_impl.removeIdentityMapping;
    pub const getPhysicalAddress = mmu_impl.getPhysicalAddress;
    pub const getMemoryMap = mmu_impl.getMemoryMap;
    pub const mapPage = mmu_impl.mapPage;
    pub const unmapPage = mmu_impl.unmapPage;
};

pub const platform = struct {
    pub const initializeConsole = platform_impl.initializeConsole;
    pub const initializeTimer = platform_impl.initializeTimer;
    pub const setColor = platform_impl.setColor;
    pub const writer = platform_impl.writer;
};
