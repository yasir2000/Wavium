/*
 * Prompt 02 x86_64 reset skeleton.
 *
 * This assembly file is a documentation-grade execution sketch only.
 * It is not wired into the build graph yet.
 */

.global wavium_x86_64_reset_vector
.type wavium_x86_64_reset_vector, @function

.global _start
.type _start, @function
_start:
    jmp wavium_x86_64_reset_vector

wavium_x86_64_reset_vector:
    /* Mask interrupts while startup state is undefined. */
    cli

    /* Placeholder transfer to startup stage. */
    jmp wavium_x86_64_startup_entry
