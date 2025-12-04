ENTRY(_start_asm)
OUTPUT_FORMAT(elf32-i386)

KERNEL_VIRTUAL_ADDRESS = 0xC0000000;

SECTIONS
{
    . = 2M;

	_kernel_start = .;
	.multiboot : AT (ADDR (.multiboot)) {
		KEEP(*(.multiboot))
	}
	/*.multiboot.data ALIGN (4) : AT (ADDR (.multiboot.data)) {
		*(.multiboot.data)
	}

	.multiboot.text ALIGN (4K) : AT (ADDR (.multiboot.text)) {
		*(.multiboot.text)
	}

	.paging_setup ALIGN (4K) : AT (ADDR (.paging_setup)) {
		*(.paging_setup)
	}*/

	/*. += KERNEL_VIRTUAL_ADDRESS;*/
	.text ALIGN (4K) : AT (ADDR (.text)/* - KERNEL_VIRTUAL_ADDRESS*/)
	{
		*(.text)
	}
	.rodata ALIGN (4K) : AT (ADDR (.rodata)/* - KERNEL_VIRTUAL_ADDRESS*/)
	{
		*(.rodata)
	}
	.data ALIGN (4K) : AT (ADDR (.data)/* - KERNEL_VIRTUAL_ADDRESS*/)
	{
		*(.data)
	}
	.bss ALIGN (4K) : AT (ADDR (.bss)/* - KERNEL_VIRTUAL_ADDRESS*/)
	{
		*(.bss)
		*(.bootstrap_stack)
	}
	_kernel_end = .;
}
