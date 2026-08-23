const arch = @import("arch");
const limine = @import("main.zig");

const MAX_BOOT_MODULES = 16;

var bootModules: [MAX_BOOT_MODULES]arch.BootModule = undefined;
var bootModuleCount: usize = 0;
var bootModulesCached: bool = false;

pub fn cacheBootModules() void {
    if (bootModulesCached) {
        return;
    }

    const response = limine.module_request.response orelse {
        bootModuleCount = 0;
        bootModulesCached = true;
        return;
    };

    const available_modules = @min(@as(usize, @intCast(response.module_count)), MAX_BOOT_MODULES);
    for (0..available_modules) |module_index| {
        bootModules[module_index] = convertLimineModule(response.modules[module_index]);
    }

    bootModuleCount = available_modules;
    bootModulesCached = true;
}

pub fn getBootModule(index: usize) ?arch.BootModule {
    ensureBootModulesCached();
    if (index >= bootModuleCount) {
        return null;
    }
    return bootModules[index];
}

pub fn getBootModuleCount() usize {
    ensureBootModulesCached();
    return bootModuleCount;
}

fn ensureBootModulesCached() void {
    if (!bootModulesCached) {
        @panic("Boot modules were not cached before runtime access");
    }
}

pub fn reserveBootModules() arch.EarlyAllocError!void {
    const response = limine.module_request.response orelse return;
    const available_modules = @min(@as(usize, @intCast(response.module_count)), MAX_BOOT_MODULES);

    for (0..available_modules) |module_index| {
        const boot_module = convertLimineModule(response.modules[module_index]);
        if (boot_module.physical_start >= boot_module.physical_end) {
            continue;
        }

        try arch.early_allocator.reserve(
            boot_module.physical_start,
            boot_module.physical_end - boot_module.physical_start,
            arch.ReservedMapRegionType.BOOTLOADER_DATA,
        );
    }
}

fn convertLimineModule(file: *const limine.File) arch.BootModule {
    const virtual_start = @intFromPtr(file.address);
    const physical_start = getPhysicalAddressFromLiminePointer(virtual_start);
    return .{
        .physical_start = physical_start,
        .physical_end = physical_start + @as(usize, @intCast(file.size)),
    };
}

fn getPhysicalAddressFromLiminePointer(address: usize) usize {
    const hhdm_offset = limine.getHhdmOffset();
    if (hhdm_offset != 0 and address >= hhdm_offset) {
        return address - hhdm_offset;
    }

    return address;
}
