/* Prompt 02 placeholder linker script for RISC-V64 boot entry. */
ENTRY(_start)

SECTIONS
{
    . = 0x80200000;
    .text : { *(.text*) }
    .rodata : { *(.rodata*) }
    .data : { *(.data*) }
    .bss : { *(.bss*) *(COMMON) }
}
