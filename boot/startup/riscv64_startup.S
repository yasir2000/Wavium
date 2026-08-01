/*
 * Prompt 02 riscv64 startup skeleton.
 *
 * Documentation-grade execution sketch mirroring the x86_64 startup skeleton.
 */

.global wavium_riscv64_startup_entry
.type wavium_riscv64_startup_entry, @function
wavium_riscv64_startup_entry:
    /* Establish a temporary stack. Actual symbol wiring comes in later milestone. */
    la sp, wavium_riscv64_temp_stack_top

    /* Prompt 02 ABI contract: pass handoff payload pointer in a0. */
    la a0, wavium_riscv64_handoff_payload

    /* Placeholder handoff to runtime transfer stub. */
    j wavium_riscv64_runtime_handoff

.global wavium_riscv64_runtime_handoff
.type wavium_riscv64_runtime_handoff, @function
wavium_riscv64_runtime_handoff:
    wfi
    j wavium_riscv64_runtime_handoff

.bss
.align 4
wavium_riscv64_temp_stack:
    .space 4096
wavium_riscv64_temp_stack_top:

.align 4
wavium_riscv64_handoff_payload:
    .dword 0
