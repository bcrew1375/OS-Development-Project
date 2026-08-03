const abi = @import("abi");

pub const AddressSpace = struct {
    handle: u32,
};

pub const MemoryObject = struct {
    handle: u32,
};

pub const MAP_READ = abi.syscall.MAP_READ;
pub const MAP_WRITE = abi.syscall.MAP_WRITE;
pub const MAP_EXECUTE = abi.syscall.MAP_EXECUTE;

pub fn createAddressSpace() ?AddressSpace {
    const handle = abi.syscall.syscall3(
        @intFromEnum(abi.syscall.SyscallNumber.create_address_space),
        0,
        0,
        0,
    );

    if (handle == abi.syscall.INVALID_HANDLE) {
        return null;
    }

    return .{ .handle = handle };
}

pub fn mapRegion(address_space: AddressSpace, virtual_start: usize, size_in_bytes: usize) bool {
    const result = abi.syscall.syscall3(
        @intFromEnum(abi.syscall.SyscallNumber.map_memory),
        address_space.handle,
        virtual_start,
        size_in_bytes,
    );

    return result == abi.syscall.SYSCALL_SUCCESS;
}

pub fn createMemoryObject(size_in_bytes: usize) ?MemoryObject {
    const handle = abi.syscall.syscall3(
        @intFromEnum(abi.syscall.SyscallNumber.create_memory_object),
        size_in_bytes,
        0,
        0,
    );

    if (handle == abi.syscall.INVALID_HANDLE) {
        return null;
    }

    return .{ .handle = handle };
}

pub fn mapMemoryObject(
    address_space: AddressSpace,
    memory_object: MemoryObject,
    virtual_start: usize,
    size_in_bytes: usize,
    permission_flags: u32,
) bool {
    const result = abi.syscall.syscall5(
        @intFromEnum(abi.syscall.SyscallNumber.map_memory_object),
        address_space.handle,
        memory_object.handle,
        virtual_start,
        size_in_bytes,
        permission_flags,
    );

    return result == abi.syscall.SYSCALL_SUCCESS;
}
