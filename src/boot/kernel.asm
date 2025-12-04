[BITS 32]

global _start_asm
extern kernelMain

;section .text
_start_asm:
    cli

    mov esp, 0x300000
    mov al, 0x11        ; ICW1: start init, edge triggered, ICW4 needed
    out 0x20, al
    mov al, 0x20        ; ICW2: interrupt vector offset (0x20 = IRQ0 → INT 0x20)
    out 0x21, al
    mov al, 0x04        ; ICW3: bitmask of connected slaves (bit 2 = IRQ2)
    out 0x21, al
    mov al, 0x01        ; ICW4: 8086 mode
    out 0x21, al
    ; End remap of the master PIC.

    call kernelMain
    jmp $
