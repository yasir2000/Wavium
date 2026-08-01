//! Thin re-export facade for the "wasm" subsystem named in the original
//! Prompt 01 top-level repository layout. The real implementation lives in
//! modules/wavium-wasm/src/lib.zig (the WASM engine contract); this file
//! exists only so callers can reach it from the top-level layout without
//! duplicating any logic.
const std = @import("std");

pub const wasm = @import("wavium-wasm");

test "wasm facade re-exports modules/wavium-wasm" {
    const cfg = wasm.EngineConfig{};
    try std.testing.expectEqual(wasm.Backend.interpreter, cfg.backend);
}
