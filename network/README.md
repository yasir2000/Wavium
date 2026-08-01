# Network

Status: facade

This directory is a thin re-export facade over `modules/wavium-fabric/src/lib.zig` (message framing / bounded backpressure queue), matching the original Prompt 01 top-level layout. See `lib.zig` in this folder for the re-export; the actual implementation and tests live in the `modules/wavium-fabric` package.
