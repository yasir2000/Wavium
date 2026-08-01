# Storage

Status: facade

This directory is a thin re-export facade over `modules/wavium-state/src/lib.zig` (append-only actor state log with snapshot serialize/replay), matching the original Prompt 01 top-level layout. See `lib.zig` in this folder for the re-export; the actual implementation and tests live in the `modules/wavium-state` package.
