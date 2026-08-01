# Boot

Status: prompt-02 scaffold in progress

This directory tracks the bare-metal boot system milestone.

## Layout

- `reset/`: reset vector and first-instruction responsibilities
- `startup/`: architecture startup sequencing
- `cpu/`: CPU initialization contracts
- `memory/`: early memory map and stack bootstrap contracts
- `loader/`: runtime image verification and transfer contracts
- `entry/`: freestanding entrypoint and linker scripts
- `tests/`: boot scaffold smoke checks
- `test-image/`: test boot image scaffolding

## Current implementation snapshot

- Architecture-targeted reset stubs exist for x86_64, aarch64, and riscv64.
- Architecture-targeted startup stubs emit a typed `BootHandoff` model.
- x86_64 startup supports profile-based handoff defaults (`qemu_pc`, `uefi_vm`).
- Loader handoff contract validation is wired and enforced in `bootstrap()`.
- Root boot module API is exposed through `boot/root.zig`.
- Assembly reset/startup skeletons exist and are compiled/linked for all three architectures: x86_64, aarch64, riscv64.
- `cpu/contract.zig` and `memory/contract.zig` provide real (non-placeholder) per-architecture CPU-init and early-memory-layout contracts.
- `loader/contract.zig` provides an image header format with checksum-based integrity validation and a halt-only failure policy.

## Local validation

- `PATH="/c/Users/yasir/zig-x86_64-windows-0.17.0-dev:$PATH" zig build --build-file boot/build.zig test`
- `PATH="/c/Users/yasir/zig-x86_64-windows-0.17.0-dev:$PATH" zig build --build-file boot/build.zig test-image`
- `PATH="/c/Users/yasir/zig-x86_64-windows-0.17.0-dev:$PATH" zig build --build-file boot/build.zig asm-skeleton-x86_64`
- `PATH="/c/Users/yasir/zig-x86_64-windows-0.17.0-dev:$PATH" zig build --build-file boot/build.zig boot-image-x86_64`
- `PATH="/c/Users/yasir/zig-x86_64-windows-0.17.0-dev:$PATH" zig build --build-file boot/build.zig boot-image-symbols-x86_64`
- `PATH="/c/Users/yasir/zig-x86_64-windows-0.17.0-dev:$PATH" zig build --build-file boot/build.zig clean-boot-artifacts`
- `PATH="/c/Users/yasir/zig-x86_64-windows-0.17.0-dev:$PATH" zig build --build-file boot/build.zig boot-verify-x86_64`
- `PATH="/c/Users/yasir/zig-x86_64-windows-0.17.0-dev:$PATH" zig build --build-file boot/build.zig boot-verify-aarch64`
- `PATH="/c/Users/yasir/zig-x86_64-windows-0.17.0-dev:$PATH" zig build --build-file boot/build.zig boot-verify-riscv64`
- `PATH="/c/Users/yasir/zig-x86_64-windows-0.17.0-dev:$PATH" zig build --build-file boot/build.zig boot-verify-all`

The `asm-skeleton-<arch>` step is opt-in and compiles assembly skeleton objects plus a freestanding handoff contract stub, for `<arch>` in `x86_64`, `aarch64`, `riscv64`.
Object outputs are build-managed temporary artifacts (not emitted into `boot/test-image`).

The `boot-image-<arch>` step is opt-in and links a freestanding ELF image from the reset/startup assembly skeletons and the matching `entry/linker/<arch>.ld` script.
Linked ELF output path: `boot/test-image/wavium_<arch>_boot.elf`.
The symbol-check step enforces this canonical location and fails if a legacy root-level `test-image/wavium_<arch>_boot.elf` exists.

The `boot-image-symbols-<arch>` step links the same image and validates the symbol contract via ELF existence plus required source-label checks.
Note: current Zig `objdump` in this environment does not provide usable ELF symbol-table output.

The `clean-boot-artifacts` step removes stale boot ELF outputs (all three architectures) from both legacy root and canonical boot-local paths.

The `boot-verify-<arch>` step is the aggregate flow per architecture: cleanup, link boot image, then run symbol-contract verification.
The `boot-verify-all` step runs `boot-verify-x86_64`, `boot-verify-aarch64`, and `boot-verify-riscv64` in one invocation.

Current x86_64 startup skeleton now loads a placeholder handoff payload address into `rdi` before transferring to the runtime handoff label. The aarch64 and riscv64 skeletons follow the same pattern using `x0` and `a0` respectively.

## Constraints

- no libc
- no POSIX
- no syscalls
- no kernel/runtime dependency
- Zig freestanding principles for boot path code

## TODO

- Replace placeholder reset/startup stubs with real, board-validated architecture assembly paths.
- Wire assembly skeletons into runtime transfer tests beyond symbol-contract checks (e.g. QEMU boot).
- Replace placeholder linker scripts with board and platform memory maps.
- Add QEMU-based and hardware smoke tests for boot image execution.
