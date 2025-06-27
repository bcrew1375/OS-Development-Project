ENTRY(_start)
OUTPUT_FORMAT(elf32-i386)
SECTIONS
{
    . = 1M;

    .kernel : {
        KEEP(*(.text))
        KEEP(*(.rodata))
        KEEP(*(.data))
        KEEP(*(COMMON))
        KEEP(*(.bss))
    }

    .text : ALIGN(4096)
    {
        *(.text*)
    }

    .rodata : ALIGN(4096)
    {
        *(.rodata*)
    }

    .data : ALIGN(4096)
    {
        *(.data*)
    }

    .bss : ALIGN(4096)
    {
        *(COMMON)
        *(.bss*)
    }

    /DISCARD/ : {
        *(.comment)
        *(.eh_frame)
        *(.note*)
        *(.debug*)
    }
}