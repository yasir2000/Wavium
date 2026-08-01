//! Thin re-export facade for the "sdk" subsystem named in the original
//! Prompt 01 top-level repository layout. The real implementation lives in
//! modules/wavium-sdk/src/lib.zig (the target-language SDK registry); this
//! file exists only so callers can reach it from the top-level layout
//! without duplicating any logic.
const std = @import("std");

pub const sdk = @import("wavium-sdk");

test "sdk facade re-exports modules/wavium-sdk" {
    try std.testing.expectEqual(@as(usize, 9), sdk.sdkCount());
    try std.testing.expectEqual(sdk.TargetLanguage.zig, sdk.TargetLanguage.zig);
}
