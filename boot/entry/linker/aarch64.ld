/* Prompt 02 placeholder linker script for ARM64 boot entry. */
ENTRY(_start)

SECTIONS
{
    . = 0x00080000;
    .text : { *(.text*) }
    .rodata : { *(.rodata*) }
    .data : { *(.data*) }
    .bss : { *(.bss*) *(COMMON) }
}
