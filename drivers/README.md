# Drivers

Status: facade

This directory is a thin re-export facade over `modules/wavium-hal/src/lib.zig` (probe/attach/detach driver lifecycle API), matching the original Prompt 01 top-level layout. See `lib.zig` in this folder for the re-export; the actual implementation and tests live in the `modules/wavium-hal` package.
