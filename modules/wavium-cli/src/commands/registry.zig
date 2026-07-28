const std = @import("std");

pub const Command = enum {
    create,
    build,
    package,
    run,
    inspect,
    debug,
    benchmark,
};

pub fn parse(name: []const u8) !Command {
    if (std.mem.eql(u8, name, "create")) return .create;
    if (std.mem.eql(u8, name, "build")) return .build;
    if (std.mem.eql(u8, name, "package")) return .package;
    if (std.mem.eql(u8, name, "run")) return .run;
    if (std.mem.eql(u8, name, "inspect")) return .inspect;
    if (std.mem.eql(u8, name, "debug")) return .debug;
    if (std.mem.eql(u8, name, "benchmark")) return .benchmark;
    return error.UnknownCommand;
}

pub fn commandName(cmd: Command) []const u8 {
    return switch (cmd) {
        .create => "create",
        .build => "build",
        .package => "package",
        .run => "run",
        .inspect => "inspect",
        .debug => "debug",
        .benchmark => "benchmark",
    };
}
