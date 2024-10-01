[BITS 32]

global _start
extern kernelMain

CODE_SEG equ 0x08
DATA_SEG equ 0x10

_start:
    ; Setup permanent segments and stack pointer.
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov ebp, 0x00200000
    mov esp, ebp

    call kernelMain

    jmp $

times 512-($ - $$) db 0