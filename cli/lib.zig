//! Thin re-export facade for the "cli" subsystem named in the original
//! Prompt 01 top-level repository layout. The real implementation lives in
//! modules/wavium-cli/src/main.zig (command registry + dispatch); this
//! file exists only so callers can reach it from the top-level layout
//! without duplicating any logic.
const std = @import("std");

pub const cli = @import("wavium-cli");

test "cli facade re-exports modules/wavium-cli dispatch" {
    const out = try cli.dispatch("run");
    try std.testing.expectEqualStrings("wcoe.run: execute component in local runtime", out);
}
