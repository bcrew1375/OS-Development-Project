const gdt = @import("../interrupts/global_descriptor_table.zig");

pub fn unrecoverableHalt() noreturn {
    asm volatile (
        \\cli
        \\hlt
    );
    unreachable;
}

pub fn enterUserMode(entry_point: usize, stack_top: usize, argument0: usize) noreturn {
    asm volatile (
        \\cli
        \\mov %[userDataSelector], %ax
        \\mov %ax, %ds
        \\mov %ax, %es
        \\mov %ax, %fs
        \\mov %ax, %gs
        \\push %[userDataSelector]
        \\push %[stackTop]
        \\pushfq
        \\pop %rax
        \\or $0x200, %rax
        \\push %rax
        \\push %[userCodeSelector]
        \\push %[entryPoint]
        \\mov %[argument0], %rdi
        \\iretq
        :
        : [userDataSelector] "i" (gdt.USER_DATA_SELECTOR),
          [userCodeSelector] "i" (gdt.USER_CODE_SELECTOR),
          [stackTop] "r" (stack_top),
          [entryPoint] "r" (entry_point),
          [argument0] "r" (argument0),
        : .{ .rax = true, .memory = true });
    unreachable;
}
