//! Thin re-export facade for the "runtime" subsystem named in the original
//! Prompt 01 top-level repository layout. The real implementation lives in
//! modules/wavium-component/src/runtime.zig (the decoupled
//! ExecutionBackend/ComponentRuntime/RunningComponent execution runtime),
//! re-exported here via modules/wavium-component/src/lib.zig; this file
//! exists only so callers can reach it from the top-level layout without
//! duplicating any logic.
const std = @import("std");

pub const runtime = @import("wavium-component");

test "runtime facade re-exports modules/wavium-component runtime" {
    const err: runtime.RuntimeError = error.NotInstantiated;
    try std.testing.expectEqual(runtime.RuntimeError.NotInstantiated, err);
}
