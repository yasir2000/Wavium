# Reset

Status: scaffold with contract stubs

## Purpose

Define reset-vector responsibilities for each supported architecture.

## Implemented now

- Architecture stubs for x86_64, aarch64, and riscv64.
- Reset-stage contract fields for interrupt mask/MMU/cache state.
- Per-architecture reset-vector alignment checks.
- Validation helper that enforces pre-startup reset invariants.
- Assembly reset-vector skeletons for all three architectures: `x86_64_reset.S`, `aarch64_reset.S`, `riscv64_reset.S`.
- Each skeleton is compiled and linked via `boot/build.zig` (`asm-skeleton-<arch>`, `boot-image-<arch>`).

## TODO

- Replace documentation-grade assembly skeletons with real, board-validated reset-vector entry code.
- Add explicit general-purpose/system register handoff snapshots.
- Tie reset validation to board-specific boot ROM expectations.
