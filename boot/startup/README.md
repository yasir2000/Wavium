# Startup

Status: scaffold with handoff contract

## Purpose

Coordinate architecture startup sequencing after reset and before runtime loader transfer.

## Implemented now

- Startup builders per architecture that consume reset stage data.
- Typed `BootHandoff` generation with memory map + stack metadata.
- Contract validation before returning a handoff model.
- Loader-facing handoff validation integration in boot entry path.
- Assembly startup skeletons for all three architectures: `x86_64_startup.S`, `aarch64_startup.S`, `riscv64_startup.S`.
- Each skeleton establishes a temporary stack, loads a placeholder handoff payload into the architecture's ABI arg0 register, and jumps to a runtime-handoff label.

## TODO

- Replace documentation-grade assembly skeletons with real bootstrap flow (page tables, real stack region, real payload).
- Add interrupt vector table and trap handler early-install sequencing.
- Add architecture-specific startup failure telemetry hooks.
