const ctx_mod = @import("context.zig");

pub fn execute(ctx: ctx_mod.CommandContext) []const u8 {
    return if (ctx.dry_run)
        "wavium.deploy[dry-run]: would deploy packaged component"
    else
        "wavium.deploy: deploy packaged component";
}
