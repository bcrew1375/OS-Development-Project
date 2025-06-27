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
    ;mov esp, 0x08000000
    mov ebp, 0x08000000
    ;and esp, 0xFFFFFFF0   ; 16-byte alignment
    ;sub esp, 4            ; prepare for `call` pushing 4 bytes
    ;push ebp              ; save previous EBP
    ;mov ebp, esp          ; establish correct base pointer
    mov esp, ebp

    mov al, 0x11        ; ICW1: start init, edge triggered, ICW4 needed
    out 0x20, al
    mov al, 0x20        ; ICW2: interrupt vector offset (0x20 = IRQ0 → INT 0x20)
    out 0x21, al
    mov al, 0x04        ; ICW3: bitmask of connected slaves (bit 2 = IRQ2)
    out 0x21, al
    mov al, 0x01        ; ICW4: 8086 mode
    out 0x21, al
    ; End remap of the master PIC.

    ;push ebx
    ;push esi
    ;push edi
    call kernelMain
    ;pop edi
    ;pop esi
    ;pop ebx
    ;pop ebp
    ;cli
    ;hlt
    sti
    jmp $

times 512-($ - $$) db 0