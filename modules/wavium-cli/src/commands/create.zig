const ctx_mod = @import("context.zig");

pub fn execute(ctx: ctx_mod.CommandContext) []const u8 {
    return if (ctx.dry_run)
        "wcoe.create[dry-run]: would scaffold component workspace"
    else
        "wcoe.create: scaffold component workspace";
}
