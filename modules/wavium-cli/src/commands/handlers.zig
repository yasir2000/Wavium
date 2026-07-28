const std = @import("std");
const registry = @import("registry.zig");
const context = @import("context.zig");
const create = @import("create.zig");
const build_cmd = @import("build.zig");
const package_cmd = @import("package.zig");
const run_cmd = @import("run.zig");
const inspect_cmd = @import("inspect.zig");
const debug_cmd = @import("debug.zig");
const benchmark_cmd = @import("benchmark.zig");

pub fn execute(cmd: registry.Command, ctx: context.CommandContext) []const u8 {
    _ = std;
    return switch (cmd) {
        .create => create.execute(ctx),
        .build => build_cmd.execute(ctx),
        .package => package_cmd.execute(ctx),
        .run => run_cmd.execute(ctx),
        .inspect => inspect_cmd.execute(ctx),
        .debug => debug_cmd.execute(ctx),
        .benchmark => benchmark_cmd.execute(ctx),
    };
}
