const std = @import("std");
const arch = @import("arch");
const kernel = @import("kernel_common");

fn testSetup() void {
    arch.early_allocator.initialize() catch {
        std.debug.print("Test initialization failed.", .{});
    };
}

test "Virtual Memory Manager: Map Region Adds Virtual Memory Area" {
    testSetup();
    try kernel.pmm.initialize();

    var vmaBacking: [2]kernel.vmm.VirtualMemoryArea = undefined;
    var addressSpace = kernel.vmm.AddressSpace{
        .VMAList = &vmaBacking,
        .length = 0,
    };
    kernel.vmm.setAddressSpace(&addressSpace);

    const permissions = kernel.vmm.MemoryPermissions{
        .readable = true,
        .writeable = true,
        .executable = false,
        .user_accessible = false,
    };

    try kernel.vmm.map(&addressSpace, 0x10000000, 0x10400000, permissions);
    try std.testing.expectEqual(@as(usize, 1), addressSpace.length);
    try std.testing.expectEqual(@as(u64, 0x10000000), addressSpace.VMAList[0].start_address);
    try std.testing.expectEqual(@as(u64, 0x10400000), addressSpace.VMAList[0].end_address);
}

test "Virtual Memory Manager: Overlapping Region Returns Error" {
    testSetup();
    try kernel.pmm.initialize();

    var vmaBacking: [2]kernel.vmm.VirtualMemoryArea = undefined;
    var addressSpace = kernel.vmm.AddressSpace{
        .VMAList = &vmaBacking,
        .length = 0,
    };
    kernel.vmm.setAddressSpace(&addressSpace);

    const permissions = kernel.vmm.MemoryPermissions{
        .readable = true,
        .writeable = true,
        .executable = false,
        .user_accessible = false,
    };

    try kernel.vmm.map(&addressSpace, 0x10000000, 0x10400000, permissions);
    const overlapping = kernel.vmm.map(&addressSpace, 0x10200000, 0x10600000, permissions);
    try std.testing.expectError(error.OverlappingVirtualMemoryArea, overlapping);
}

test "Virtual Memory Manager: Undefined Address Space Returns Error" {
    testSetup();
    try kernel.pmm.initialize();

    var vmaBacking: [0]kernel.vmm.VirtualMemoryArea = undefined;
    var addressSpace = kernel.vmm.AddressSpace{
        .VMAList = &vmaBacking,
        .length = 0,
    };
    kernel.vmm.setAddressSpace(&addressSpace);

    const permissions = kernel.vmm.MemoryPermissions{
        .readable = true,
        .writeable = true,
        .executable = false,
        .user_accessible = false,
    };

    const result = kernel.vmm.map(&addressSpace, 0x10000000, 0x10400000, permissions);
    try std.testing.expectError(error.UndefinedAddressSpace, result);
}

test "Virtual Memory Manager: Unmap Removes Virtual Memory Area" {
    testSetup();
    try kernel.pmm.initialize();

    var vmaBacking: [2]kernel.vmm.VirtualMemoryArea = undefined;
    var addressSpace = kernel.vmm.AddressSpace{
        .VMAList = &vmaBacking,
        .length = 0,
    };
    kernel.vmm.setAddressSpace(&addressSpace);

    const permissions = kernel.vmm.MemoryPermissions{
        .readable = true,
        .writeable = true,
        .executable = false,
        .user_accessible = false,
    };

    try kernel.vmm.map(&addressSpace, 0x10000000, 0x10400000, permissions);
    try kernel.vmm.map(&addressSpace, 0x20000000, 0x20400000, permissions);
    try std.testing.expectEqual(@as(usize, 2), addressSpace.length);

    kernel.vmm.unmap(&addressSpace, 0x10000000, 0x10400000);
    try std.testing.expectEqual(@as(usize, 1), addressSpace.length);
    try std.testing.expectEqual(@as(u64, 0x20000000), addressSpace.VMAList[0].start_address);
}

test "Virtual Memory Manager: Unmap Non-Existent Region Does Nothing" {
    testSetup();
    try kernel.pmm.initialize();

    var vmaBacking: [2]kernel.vmm.VirtualMemoryArea = undefined;
    var addressSpace = kernel.vmm.AddressSpace{
        .VMAList = &vmaBacking,
        .length = 0,
    };
    kernel.vmm.setAddressSpace(&addressSpace);

    const permissions = kernel.vmm.MemoryPermissions{
        .readable = true,
        .writeable = true,
        .executable = false,
        .user_accessible = false,
    };

    try kernel.vmm.map(&addressSpace, 0x10000000, 0x10400000, permissions);
    kernel.vmm.unmap(&addressSpace, 0xdead0000, 0xdead4000);
    try std.testing.expectEqual(@as(usize, 1), addressSpace.length);
}
