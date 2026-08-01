# Memory

Status: contract implemented

## Purpose

Define early boot memory setup before runtime image loading.

## Implemented now

- `contract.zig` defines `EarlyMemoryLayout` derived from the typed `BootHandoff` memory regions.
- `pageTableStrategyForArch` selects a per-architecture strategy (`identity_map_low` for x86_64/aarch64, `identity_map_flat` for riscv64).
- `validateEarlyMemoryLayout` enforces non-empty regions and requires a `.runtime` region to be present before handoff.
- Covered by boot smoke tests in `boot/tests/boot_smoke.zig`.

## TODO

- Define real page-table bootstrap code (currently a strategy label, not executable page-table construction).
- Add memory-protection enforcement (read-only/no-execute) invariants for runtime loader.
