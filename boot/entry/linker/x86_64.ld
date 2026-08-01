/* Prompt 02 placeholder linker script for x86_64 boot entry. */
ENTRY(_start)

SECTIONS
{
    . = 0x00100000;
    .text : { *(.text*) }
    .rodata : { *(.rodata*) }
    .data : { *(.data*) }
    .bss : { *(.bss*) *(COMMON) }
}
