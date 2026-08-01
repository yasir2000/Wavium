/*
 * Prompt 02 riscv64 reset skeleton.
 *
 * Documentation-grade execution sketch mirroring the x86_64 reset skeleton.
 * Privilege-mode (M/S) handling is intentionally simplified for this
 * milestone; a later milestone will add real privilege-mode transitions.
 */

.global wavium_riscv64_reset_vector
.type wavium_riscv64_reset_vector, @function

.global _start
.type _start, @function
_start:
    j wavium_riscv64_reset_vector

wavium_riscv64_reset_vector:
    /* Mask supervisor interrupts while startup state is undefined. */
    csrci sstatus, 0x2

    /* Placeholder transfer to startup stage. */
    j wavium_riscv64_startup_entry
