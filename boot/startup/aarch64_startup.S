/*
 * Prompt 02 aarch64 startup skeleton.
 *
 * Documentation-grade execution sketch mirroring the x86_64 startup skeleton.
 */

.global wavium_aarch64_startup_entry
.type wavium_aarch64_startup_entry, @function
wavium_aarch64_startup_entry:
    /* Establish a temporary stack. Actual symbol wiring comes in later milestone. */
    adrp x9, wavium_aarch64_temp_stack_top
    add x9, x9, :lo12:wavium_aarch64_temp_stack_top
    mov sp, x9

    /* Prompt 02 ABI contract: pass handoff payload pointer in x0. */
    adrp x0, wavium_aarch64_handoff_payload
    add x0, x0, :lo12:wavium_aarch64_handoff_payload

    /* Placeholder handoff to runtime transfer stub. */
    b wavium_aarch64_runtime_handoff

.global wavium_aarch64_runtime_handoff
.type wavium_aarch64_runtime_handoff, @function
wavium_aarch64_runtime_handoff:
    wfe
    b wavium_aarch64_runtime_handoff

.bss
.align 4
wavium_aarch64_temp_stack:
    .space 4096
wavium_aarch64_temp_stack_top:

.align 4
wavium_aarch64_handoff_payload:
    .xword 0
