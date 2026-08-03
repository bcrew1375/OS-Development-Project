pub const SyscallNumber = enum(u32) {
    debug_write = 0,
    exit = 1,
    create_address_space = 10,
    map_memory = 11,
    create_memory_object = 12,
    map_memory_object = 13,
    _,
};

pub const EXIT_SUCCESS: u32 = 0;
pub const EXIT_FAILURE: u32 = 1;
pub const INVALID_HANDLE: u32 = 0;
pub const SYSCALL_SUCCESS: u32 = 0;
pub const SYSCALL_FAILURE: u32 = 1;
pub const MAP_READ: u32 = 1 << 0;
pub const MAP_WRITE: u32 = 1 << 1;
pub const MAP_EXECUTE: u32 = 1 << 2;

pub fn syscall3(number: u32, argument0: usize, argument1: usize, argument2: usize) callconv(.c) u32 {
    return asm volatile (
        \\int $0x80
        : [return_value] "={eax}" (-> u32),
        : [number] "{eax}" (number),
          [argument0] "{ebx}" (argument0),
          [argument1] "{ecx}" (argument1),
          [argument2] "{edx}" (argument2),
        : .{ .memory = true });
}

pub fn syscall5(number: u32, argument0: usize, argument1: usize, argument2: usize, argument3: usize, argument4: usize) callconv(.c) u32 {
    return asm volatile (
        \\int $0x80
        : [return_value] "={eax}" (-> u32),
        : [number] "{eax}" (number),
          [argument0] "{ebx}" (argument0),
          [argument1] "{ecx}" (argument1),
          [argument2] "{edx}" (argument2),
          [argument3] "{esi}" (argument3),
          [argument4] "{edi}" (argument4),
        : .{ .memory = true });
}
