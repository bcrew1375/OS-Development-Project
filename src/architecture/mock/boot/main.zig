const arch = @import("arch");

pub fn finishBoot() void {}

pub fn getBootModuleCount() usize {
    return 0;
}

pub fn getBootModule(index: usize) ?arch.BootModule {
    _ = index;
    return null;
}
