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

    mov al, 00010001b
    out 0x20, al ; Tell Master PIC

    mov al, 0x20 ; Interrupt 0x20 is where master ISR should start.
    out 0x21, al

    mov al, 00000001b
    out 0x21, al
    ; End remap of the master PIC.

    call kernelMain

    jmp $

times 512-($ - $$) db 0