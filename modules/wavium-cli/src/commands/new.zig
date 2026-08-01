const ctx_mod = @import("context.zig");

pub fn execute(ctx: ctx_mod.CommandContext) []const u8 {
    return if (ctx.dry_run)
        "wavium.new[dry-run]: would scaffold component from template"
    else
        "wavium.new: scaffold component from template";
}
