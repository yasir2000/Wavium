const std = @import("std");
const registry = @import("commands/registry.zig");
const handlers = @import("commands/handlers.zig");
const context = @import("commands/context.zig");

pub fn dispatch(command_name: []const u8) ![]const u8 {
    const cmd = try registry.parse(command_name);
    return handlers.execute(cmd, .{});
}

pub fn dispatchWithContext(command_name: []const u8, ctx: context.CommandContext) ![]const u8 {
    const cmd = try registry.parse(command_name);
    return handlers.execute(cmd, ctx);
}

pub fn main() !void {
    var args = std.process.args();
    _ = args.next();

    const stdout = std.io.getStdOut().writer();
    const command = args.next() orelse {
        try stdout.print("usage: wavium <create|new|init|build|test|package|deploy|run|inspect|debug|benchmark>\n", .{});
        return;
    };

    const out = dispatch(command) catch |err| {
        if (err == error.UnknownCommand) {
            try stdout.print("unknown command: {s}\n", .{command});
            return;
        }
        return err;
    };
    try stdout.print("{s}\n", .{out});
}

test "cli command list includes run" {
    try std.testing.expectEqualStrings("run", registry.commandName(.run));
}

test "dispatch run command" {
    const out = try dispatch("run");
    try std.testing.expect(std.mem.indexOf(u8, out, "wcoe.run") != null);
}

test "dispatch create dry-run command" {
    const out = try dispatchWithContext("create", .{ .dry_run = true });
    try std.testing.expect(std.mem.indexOf(u8, out, "dry-run") != null);
}

test "dispatch unknown command fails" {
    try std.testing.expectError(error.UnknownCommand, dispatch("invalid"));
}

test "dispatch new command" {
    const out = try dispatch("new");
    try std.testing.expect(std.mem.indexOf(u8, out, "wavium.new") != null);
}

test "dispatch deploy command" {
    const out = try dispatch("deploy");
    try std.testing.expect(std.mem.indexOf(u8, out, "wavium.deploy") != null);
}

test "dispatch init command" {
    const out = try dispatch("init");
    try std.testing.expect(std.mem.indexOf(u8, out, "wavium.init") != null);
}

test "dispatch test command" {
    const out = try dispatch("test");
    try std.testing.expect(std.mem.indexOf(u8, out, "wavium.test") != null);
    try std.testing.expectEqualStrings("test", registry.commandName(.test_run));
}
