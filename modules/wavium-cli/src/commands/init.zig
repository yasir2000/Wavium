const ctx_mod = @import("context.zig");

pub fn execute(ctx: ctx_mod.CommandContext) []const u8 {
    return if (ctx.dry_run)
        "wavium.init[dry-run]: would initialize workspace configuration"
    else
        "wavium.init: initialize workspace configuration";
}
