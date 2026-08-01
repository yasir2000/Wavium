const ctx_mod = @import("context.zig");

pub fn execute(ctx: ctx_mod.CommandContext) []const u8 {
    return if (ctx.dry_run)
        "wavium.test[dry-run]: would run component test suite"
    else
        "wavium.test: run component test suite";
}
