# Cpu

Status: contract implemented

## Purpose

Define CPU initialization contracts required before memory and loader phases.

## Implemented now

- `contract.zig` defines `CpuInitContract` per architecture (x86_64 `cr0`/`rsp`, aarch64 `sctlr_el1`/`sp`, riscv64 `mstatus`/`sp`).
- `CpuCapabilityReport` schema exposes MMU/cache-control/interrupt-masking support flags for runtime handoff.
- `validateCpuInitContract` enforces interrupts-masked-at-init and non-empty register naming invariants.
- Covered by boot smoke tests in `boot/tests/boot_smoke.zig`.

## TODO

- Wire real control-register writes into the assembly reset/startup skeletons.
- Extend capability report with real hardware feature detection (currently static per-arch defaults).
