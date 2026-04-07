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
    pub const initialize = mmu_impl.initialize;
    pub const removeIdentityMapping = mmu_impl.removeIdentityMapping;
    pub const getPhysicalAddress = mmu_impl.getPhysicalAddress;
};

pub const platform = struct {
    pub const initializeConsole = platform_impl.initializeConsole;
    pub const initializeTimer = platform_impl.initializeTimer;
    pub const writer = platform_impl.writer;
};
