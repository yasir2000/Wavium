const ctx_mod = @import("context.zig");

pub fn execute(ctx: ctx_mod.CommandContext) []const u8 {
    _ = ctx;
    return "wcoe.debug: debug runtime/component execution";
}
