const std = @import("std");

pub const ComponentLanguage = enum {
    zig,
    rust,
    javascript,
};

pub const WorkflowComponent = struct {
    name: []const u8,
    world: []const u8,
    language: ComponentLanguage,
};

pub const LoadedComponent = struct {
    definition: WorkflowComponent,
};

pub const DemoTranscript = struct {
    plan: []const u8,
    execute: []const u8,
    verify: []const u8,
    publish: []const u8,
};

pub const WorkflowHost = struct {
    world: []const u8 = "ai-agent-component",

    pub fn loadComponent(self: *const WorkflowHost, definition: WorkflowComponent) !LoadedComponent {
        if (definition.name.len == 0) return error.InvalidComponentName;
        if (!std.mem.eql(u8, definition.world, self.world)) return error.InvalidComponentWorld;

        return .{ .definition = definition };
    }

    pub fn invoke(_: *const WorkflowHost, component: LoadedComponent, stage: []const u8) []const u8 {
        return switch (component.definition.language) {
            .zig, .rust, .javascript => step(stage),
        };
    }
};

pub fn plan(input: []const u8) []const u8 {
    _ = input;
    return "plan: assemble a native workflow graph without network calls";
}

pub fn execute(input: []const u8) []const u8 {
    _ = input;
    return "execute: run the next component directly inside the host-managed flow";
}

pub fn verify(input: []const u8) []const u8 {
    _ = input;
    return "verify: confirm the workflow output without leaving the component boundary";
}

pub fn publish(input: []const u8) []const u8 {
    _ = input;
    return "publish: emit the final artifact from native state";
}

pub fn step(input: []const u8) []const u8 {
    if (std.mem.eql(u8, input, "plan")) return plan(input);
    if (std.mem.eql(u8, input, "execute")) return execute(input);
    if (std.mem.eql(u8, input, "verify")) return verify(input);
    if (std.mem.eql(u8, input, "publish")) return publish(input);
    return "component observed input";
}

pub fn runDemo() !DemoTranscript {
    const host = WorkflowHost{};

    const plan_component = try host.loadComponent(.{ .name = "planner", .world = host.world, .language = .zig });
    const execute_component = try host.loadComponent(.{ .name = "executor", .world = host.world, .language = .rust });
    const verify_component = try host.loadComponent(.{ .name = "verifier", .world = host.world, .language = .javascript });
    const publish_component = try host.loadComponent(.{ .name = "publisher", .world = host.world, .language = .zig });

    return .{
        .plan = host.invoke(plan_component, "plan"),
        .execute = host.invoke(execute_component, "execute"),
        .verify = host.invoke(verify_component, "verify"),
        .publish = host.invoke(publish_component, "publish"),
    };
}

test "agent workflow stages produce explicit outputs" {
    try std.testing.expectEqualStrings("plan: assemble a native workflow graph without network calls", plan("plan"));
    try std.testing.expectEqualStrings("execute: run the next component directly inside the host-managed flow", execute("execute"));
    try std.testing.expectEqualStrings("verify: confirm the workflow output without leaving the component boundary", verify("verify"));
    try std.testing.expectEqualStrings("publish: emit the final artifact from native state", publish("publish"));
}

test "agent dispatcher maps known stages" {
    try std.testing.expectEqualStrings("plan: assemble a native workflow graph without network calls", step("plan"));
    try std.testing.expectEqualStrings("component observed input", step("anything-else"));
}

test "agent host loads and invokes workflow components" {
    var host = WorkflowHost{};

    const plan_component = try host.loadComponent(.{ .name = "planner", .world = host.world, .language = .zig });
    try std.testing.expectError(error.InvalidComponentName, host.loadComponent(.{ .name = "", .world = host.world, .language = .zig }));
    try std.testing.expectError(error.InvalidComponentWorld, host.loadComponent(.{ .name = "planner", .world = "wrong-world", .language = .zig }));

    try std.testing.expectEqualStrings("plan: assemble a native workflow graph without network calls", host.invoke(plan_component, "plan"));
    try std.testing.expectEqualStrings("component observed input", host.invoke(plan_component, "missing-stage"));
}

test "agent host orchestration produces an end to end transcript" {
    const transcript = try runDemo();
    try std.testing.expectEqualStrings("plan: assemble a native workflow graph without network calls", transcript.plan);
    try std.testing.expectEqualStrings("execute: run the next component directly inside the host-managed flow", transcript.execute);
    try std.testing.expectEqualStrings("verify: confirm the workflow output without leaving the component boundary", transcript.verify);
    try std.testing.expectEqualStrings("publish: emit the final artifact from native state", transcript.publish);
}
