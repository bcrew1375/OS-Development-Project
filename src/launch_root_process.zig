const arch = @import("arch");
const kernel_common = @import("kernel_common");
const std = @import("std");
const abi = @import("abi");

const vmm = kernel_common.memory_management.virtual_memory;
const elf_loader = kernel_common.elf_loader;

const USER_BOOT_INFO_START: u64 = 0x0010_0000;
const USER_BOOT_INFO_END: u64 = USER_BOOT_INFO_START + 0x1000;
const USER_STACK_START: u64 = 0x0080_0000;
const USER_STACK_END: u64 = USER_STACK_START + 0x0040_0000;
const MAX_BOOT_INFO_MODULES = 16;

const RootProcessLaunchError = error{
    RootProcessModuleMissing,
    InvalidBootModuleRange,
    RootAddressSpaceMappingMissing,
} || elf_loader.ElfLoadError || arch.MmuError;

const BootInfoLayout = extern struct {
    boot_info: abi.boot_info.BootInfo,
    modules: [MAX_BOOT_INFO_MODULES]abi.boot_info.BootModuleInfo,
};

pub const PreparedRootProcess = struct {
    address_space_root: arch.AddressSpaceRoot,
    entry_point: usize,
    initial_stack_pointer: usize,
};

pub fn launchRootProcess(address_space: *vmm.AddressSpace) !noreturn {
    const prepared_root_process = try prepareRootProcess(address_space);
    enterPreparedRootProcess(prepared_root_process);
}

pub fn prepareRootProcess(address_space: *vmm.AddressSpace) !PreparedRootProcess {
    const userStackPermissions = vmm.MemoryPermissions{
        .readable = true,
        .writeable = true,
        .executable = false,
        .user_accessible = true,
    };

    const root_address_space = try arch.mmu.createAddressSpaceRoot();

    vmm.setAddressSpace(address_space);

    const root_module = arch.boot.getBootModule(0) orelse return RootProcessLaunchError.RootProcessModuleMissing;
    const entry_point = try loadRootProcessElf(root_address_space, address_space, root_module);

    try mapBootInfo(root_address_space, address_space);
    const initial_stack_page_start = USER_STACK_END - arch.mmu.getPageSize();
    try vmm.mapBootstrapContiguousInAddressSpace(
        root_address_space,
        address_space,
        initial_stack_page_start,
        USER_STACK_END,
        userStackPermissions,
    );

    const initial_stack_pointer = try initializeUserStack(root_address_space, USER_STACK_END, USER_BOOT_INFO_START);

    return .{
        .address_space_root = root_address_space,
        .entry_point = entry_point,
        .initial_stack_pointer = initial_stack_pointer,
    };
}

pub fn enterPreparedRootProcess(prepared_root_process: PreparedRootProcess) noreturn {
    arch.mmu.switchAddressSpaceRoot(prepared_root_process.address_space_root);
    arch.cpu.enterUserMode(prepared_root_process.entry_point, prepared_root_process.initial_stack_pointer);
}

fn mapBootInfo(root_address_space: arch.AddressSpaceRoot, address_space: *vmm.AddressSpace) !void {
    const bootInfoPermissions = vmm.MemoryPermissions{
        .readable = true,
        .writeable = true,
        .executable = false,
        .user_accessible = true,
    };

    try vmm.mapBootstrapContiguousInAddressSpace(
        root_address_space,
        address_space,
        USER_BOOT_INFO_START,
        USER_BOOT_INFO_END,
        bootInfoPermissions,
    );

    const module_count = @min(arch.boot.getBootModuleCount(), MAX_BOOT_INFO_MODULES);
    var layout = BootInfoLayout{
        .boot_info = .{
            .magic = abi.boot_info.BOOT_INFO_MAGIC,
            .version = abi.boot_info.BOOT_INFO_VERSION,
            .module_count = @intCast(module_count),
            .modules_address = USER_BOOT_INFO_START + @offsetOf(BootInfoLayout, "modules"),
        },
        .modules = [_]abi.boot_info.BootModuleInfo{.{
            .physical_start = 0,
            .physical_end = 0,
        }} ** MAX_BOOT_INFO_MODULES,
    };

    for (0..module_count) |module_index| {
        const module = arch.boot.getBootModule(module_index).?;
        layout.modules[module_index] = .{
            .physical_start = @intCast(module.physical_start),
            .physical_end = @intCast(module.physical_end),
        };
    }

    try writeToAddressSpace(root_address_space, USER_BOOT_INFO_START, std.mem.asBytes(&layout));
}

fn initializeUserStack(root_address_space: arch.AddressSpaceRoot, stack_top: u64, boot_info_address: u64) !usize {
    var stack_pointer = @as(usize, @intCast(stack_top));

    stack_pointer -= @sizeOf(u32);
    var boot_info_argument: u32 = @intCast(boot_info_address);
    try writeToAddressSpace(root_address_space, stack_pointer, std.mem.asBytes(&boot_info_argument));

    stack_pointer -= @sizeOf(u32);
    var fake_return_address: u32 = 0;
    try writeToAddressSpace(root_address_space, stack_pointer, std.mem.asBytes(&fake_return_address));

    return stack_pointer;
}

fn loadRootProcessElf(root_address_space: arch.AddressSpaceRoot, address_space: *vmm.AddressSpace, root_module: arch.BootModule) !usize {
    const image = getBootModuleBytes(root_module);
    const page_size: u64 = @intCast(arch.mmu.getPageSize());
    const loadable_image = try elf_loader.parseLoadableImage(image, page_size);

    for (0..loadable_image.segment_count) |segment_index| {
        try loadRootProcessSegment(root_address_space, address_space, image, try elf_loader.getLoadableSegment(image, segment_index));
    }

    return @intCast(loadable_image.entry_point);
}

fn loadRootProcessSegment(root_address_space: arch.AddressSpaceRoot, address_space: *vmm.AddressSpace, image: []const u8, segment: elf_loader.LoadableSegment) !void {
    const page_size: u64 = @intCast(arch.mmu.getPageSize());
    const virtual_start = segment.virtual_address;
    const virtual_end = try std.math.add(u64, virtual_start, segment.memory_size);
    const mapping_start = std.mem.alignBackward(u64, virtual_start, page_size);
    const mapping_end = std.mem.alignForward(u64, virtual_end, page_size);

    const final_permissions = vmm.MemoryPermissions{
        .readable = segment.permissions.readable,
        .writeable = segment.permissions.writeable,
        .executable = segment.permissions.executable,
        .user_accessible = true,
    };

    try vmm.mapBootstrapContiguousInAddressSpace(root_address_space, address_space, mapping_start, mapping_end, .{
        .readable = final_permissions.readable,
        .writeable = true,
        .executable = final_permissions.executable,
        .user_accessible = final_permissions.user_accessible,
    });

    const file_end = try std.math.add(usize, segment.file_offset, segment.file_size);
    try writeToAddressSpace(
        root_address_space,
        virtual_start,
        image[segment.file_offset..file_end],
    );
    try zeroAddressSpace(
        root_address_space,
        virtual_start + segment.file_size,
        segment.memory_size - segment.file_size,
    );

    try vmm.protectInAddressSpace(root_address_space, address_space, mapping_start, mapping_end, final_permissions);
}

fn writeToAddressSpace(root: arch.AddressSpaceRoot, virtual_address: u64, bytes: []const u8) !void {
    var written: usize = 0;
    while (written < bytes.len) {
        const destination_virtual_address = @as(usize, @intCast(virtual_address)) + written;
        const destination = try directMapPointerForAddressSpace(root, destination_virtual_address);
        const page_remaining = arch.mmu.getPageSize() - (destination_virtual_address & (arch.mmu.getPageSize() - 1));
        const write_size = @min(page_remaining, bytes.len - written);

        @memcpy(destination[0..write_size], bytes[written .. written + write_size]);
        written += write_size;
    }
}

fn zeroAddressSpace(root: arch.AddressSpaceRoot, virtual_address: u64, byte_count: u64) !void {
    var zeroed: usize = 0;
    const total: usize = @intCast(byte_count);
    while (zeroed < total) {
        const destination_virtual_address = @as(usize, @intCast(virtual_address)) + zeroed;
        const destination = try directMapPointerForAddressSpace(root, destination_virtual_address);
        const page_remaining = arch.mmu.getPageSize() - (destination_virtual_address & (arch.mmu.getPageSize() - 1));
        const zero_size = @min(page_remaining, total - zeroed);

        @memset(destination[0..zero_size], 0);
        zeroed += zero_size;
    }
}

fn directMapPointerForAddressSpace(root: arch.AddressSpaceRoot, virtual_address: usize) ![*]u8 {
    const physical_address = arch.mmu.getPhysicalAddressInAddressSpace(root, virtual_address) orelse {
        return RootProcessLaunchError.RootAddressSpaceMappingMissing;
    };
    const direct_map_address = @as(usize, @intCast(arch.mmu.getDirectMapVirtualAddress())) + physical_address;
    return @ptrFromInt(direct_map_address);
}

fn getBootModuleBytes(root_module: arch.BootModule) []const u8 {
    if (root_module.physical_start >= root_module.physical_end) {
        return &[_]u8{};
    }

    const module_size = root_module.physical_end - root_module.physical_start;
    const module_virtual_start = @as(usize, @intCast(arch.mmu.getDirectMapVirtualAddress())) + root_module.physical_start;
    return @as([*]const u8, @ptrFromInt(module_virtual_start))[0..module_size];
}
