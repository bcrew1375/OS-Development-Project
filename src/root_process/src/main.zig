pub export fn _start() callconv(.naked) noreturn {
    asm volatile (
        \\mov $0x1, %eax
        \\int $0x80
        \\jmp .
    );
}
