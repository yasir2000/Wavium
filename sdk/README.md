# Sdk

Status: facade

This directory is a thin re-export facade over `modules/wavium-sdk/src/lib.zig` (the target-language SDK registry), matching the original Prompt 01 top-level layout. See `lib.zig` in this folder for the re-export; the actual implementation and tests live in the `modules/wavium-sdk` package. The per-language SDK sources themselves live under `sdks/`.
