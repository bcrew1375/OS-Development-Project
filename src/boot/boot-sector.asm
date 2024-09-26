ORG 0x7c00
[BITS 16]

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

_start:
    jmp short start
    nop


times 33 db 0


start:
    jmp 0:step2


step2:
    cli ; Clear interrupts
    mov ax, 0x0000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti ; Enable interrupts


.load_protected:
    cli
    lgdt[gdt_descriptor]
    mov eax, cr0
    or eax, 0x00000001
    mov cr0, eax
    jmp CODE_SEG:load32


gdt_start:
gdt_null:
    dd 0x0
    dd 0x0

; Offset 0x8
gdt_code:     ; CS SHOULD POINT TO THIS.
    dw 0xffff ; Segment limit first 0-15 bits.
    dw 0      ; Base first 0-15 bits.
    db 0      ; Base 16-23 bits.
    db 0x9a   ; Access Byte.
    db 11001111b ; High 4-bit flags and the low 4-bit flags.
    db 0      ; Base 24-31 bits.

; Offset 0x10
gdt_data:     ; DS, SS, ES, FS, GS.
    dw 0xffff ; Segment limit first 0-15 bits.
    dw 0      ; Base first 0-15 bits.
    db 0      ; Base 16-23 bits.
    db 0x92   ; Access Byte.
    db 11001111b ; High 4-bit flags and the low 4-bit flags.
    db 0      ; Base 24-31 bits.

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

[BITS 32]
load32:
    ; Fast enable the A20 line.
    in al, 0x92
    or al, 0x02
    out 0x92, al

    ; Put the kernel in RAM.
    mov eax, 1            ; Start LBA = 1
    mov ebx, 0            ; Sectors to read in(0 is a special case for 256 sectors)
    mov ecx, 256          ; Track actual sector count for looping
    mov edi, 0x00100000    ; Destination address in memory = 0x00100000
    call ata_lba_read_28     ; Read the sectors

    ; Jump to the kernel
    jmp CODE_SEG:0x100000

ata_lba_read_28:
    push eax

    shr eax, 24           ; Get the highest byte of LBA
    or eax, 0xE0         ; Select master drive and LBA mode
    mov dx, 0x1F6        ; Point to the drive/head register
    out dx, al           ; Send the drive/head and high LBA bits

    mov eax, ebx          ; Move the sector count into EAX
    mov dx, 0x1F2        ; Point to the sector count register
    out dx, al           ; Send the sector count

    pop eax
    mov dx, 0x1F3        ; Point to the LBA low byte register
    out dx, al           ; Send the low byte of LBA

    mov dx, 0x1F4        ; Point to the LBA mid byte register
    shr eax, 8           ; Shift to get the middle byte
    out dx, al           ; Send the middle byte

    mov dx, 0x1F5        ; Point to the LBA high byte register
    shr eax, 16          ; Shift to get the high byte
    out dx, al           ; Send the high byte

    mov dx, 0x1F7        ; Point to the status register
.wait_for_not_busy:
    in al, dx
    test al, 0x80        ; Wait for BSY to be cleared
    jnz .wait_for_not_busy
    test al, 0x40        ; Wait for RDY to be set
    jz .wait_for_not_busy

    mov al, 0x20         ; ATA command `0x20` (Read Sectors)
    out dx, al           ; Send the read command

.next_sector:
    push ecx

    mov dx, 0x1F7        ; Point to the status register
.wait_for_data_request:
    in al, dx
    test al, 0x08
    jz .wait_for_data_request

    mov ecx, 256
    mov dx, 0x1F0
    rep insw
    pop ecx
    loop .next_sector
    ret

times 510-($ - $$) db 0
dw 0xAA55
