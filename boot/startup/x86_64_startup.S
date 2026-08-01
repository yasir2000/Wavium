/*
 * Prompt 02 x86_64 startup skeleton.
 *
 * This assembly file is a documentation-grade execution sketch only.
 * It is not wired into the build graph yet.
 */

.global wavium_x86_64_startup_entry
.type wavium_x86_64_startup_entry, @function
wavium_x86_64_startup_entry:
    /* Establish a temporary stack. Actual symbol wiring comes in later milestone. */
    lea wavium_x86_64_temp_stack_top(%rip), %rsp

    /* Prompt 02 ABI contract: pass handoff payload pointer in rdi. */
    lea wavium_x86_64_handoff_payload(%rip), %rdi

    /* Placeholder handoff to runtime transfer stub. */
    jmp wavium_x86_64_runtime_handoff

.global wavium_x86_64_runtime_handoff
.type wavium_x86_64_runtime_handoff, @function
wavium_x86_64_runtime_handoff:
    hlt
    jmp wavium_x86_64_runtime_handoff

.bss
.align 16
wavium_x86_64_temp_stack:
    .space 4096
wavium_x86_64_temp_stack_top:

.align 16
wavium_x86_64_handoff_payload:
    .quad 0
