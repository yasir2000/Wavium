# Loader

Status: contract implemented

## Purpose

Define runtime image verification and transfer of control to runtime entry.

## Implemented now

- `handoffToRuntime`/`validateHandoff` validate a `BootHandoff` before transfer.
- `ImageHeader` defines a minimal image format (magic, arch, length, checksum) with `validateImageHeader` performing magic/arch/length/checksum checks.
- `computeImageChecksum` provides a deterministic rolling checksum for integrity verification.
- `failureActionForError` defines the Prompt 02 loader failure policy: halt on any validation failure (rollback/retry deferred).
- Covered by boot smoke tests in `boot/tests/boot_smoke.zig`.

## TODO

- Replace the rolling checksum with a cryptographic integrity check (e.g. SHA-256) for production use.
- Add rollback/retry-to-previous-stage behavior (currently halt-only).
- Wire `ImageHeader` verification into the real boot image loading path (currently a standalone contract, not yet invoked from `bootstrap()`).
