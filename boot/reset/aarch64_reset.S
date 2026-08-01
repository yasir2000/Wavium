/*
 * Prompt 02 aarch64 reset skeleton.
 *
 * Documentation-grade execution sketch mirroring the x86_64 reset skeleton.
 * Privilege-level (EL) transitions are intentionally simplified for this
 * milestone; a later milestone will add real EL2/EL1 handling.
 */

.global wavium_aarch64_reset_vector
.type wavium_aarch64_reset_vector, @function

.global _start
.type _start, @function
_start:
    b wavium_aarch64_reset_vector

wavium_aarch64_reset_vector:
    /* Mask interrupts (DAIF) while startup state is undefined. */
    msr daifset, #0xf

    /* Placeholder transfer to startup stage. */
    b wavium_aarch64_startup_entry
