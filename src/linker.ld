ENTRY(_start_asm)
OUTPUT_FORMAT(elf32-i386)

KERNEL_VIRTUAL_ADDRESS = 0xC0000000;

SECTIONS
{
    . = 2M;

	.multiboot.header ALIGN(4): AT (ADDR (.multiboot.header)) {
		KEEP(*(.multiboot.header))
	}
	.multiboot.text ALIGN(4K) : AT (ADDR (.multiboot.text)) {
		KEEP(*(.multiboot.text))
	}
	
	. += KERNEL_VIRTUAL_ADDRESS;
	.text ALIGN (4K) : AT (ADDR (.text) - KERNEL_VIRTUAL_ADDRESS)
	{
		*(.text)
	}
	.rodata ALIGN (4K) : AT (ADDR (.rodata) - KERNEL_VIRTUAL_ADDRESS)
	{
		*(.rodata)
	}
	.data ALIGN (4K) : AT (ADDR (.data) - KERNEL_VIRTUAL_ADDRESS)
	{
		*(.data)
	}
	.bss ALIGN (4K) : AT (ADDR (.bss) - KERNEL_VIRTUAL_ADDRESS)
	{
		*(.bss)
		*(.bootstrap_stack)
	}
}
