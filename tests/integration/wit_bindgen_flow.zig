const std = @import("std");
const wit = @import("wavium-wit");
const bindgen = @import("wavium-bindgen");

test "wit parse to bindgen zig and rust stubs" {
    const worlds = [_]wit.WitWorld{.{ .name = "runtime", .import_count = 1, .export_count = 1 }};
    const pkg = try wit.parse("wavium:runtime", worlds[0..]);
    _ = try wit.resolveWorld(pkg, "runtime");

    const req = bindgen.GeneratorRequest{
        .namespace = pkg.namespace,
        .world = pkg.world,
        .interface_name = "storage",
        .function_name = "put",
        .payload_type = "string",
    };

    var zig_buf: [1024]u8 = undefined;
    const zig_used = try bindgen.generateBindings(req, .zig, zig_buf[0..]);
    try std.testing.expect(std.mem.indexOf(u8, zig_buf[0..zig_used], "pub const storage") != null);

    var rust_buf: [1024]u8 = undefined;
    const rust_used = try bindgen.generateBindings(req, .rust, rust_buf[0..]);
    try std.testing.expect(std.mem.indexOf(u8, rust_buf[0..rust_used], "pub mod storage") != null);
    try std.testing.expect(std.mem.indexOf(u8, rust_buf[0..rust_used], "pub struct putPayload") != null);
    try std.testing.expect(std.mem.indexOf(u8, rust_buf[0..rust_used], "pub fn abi_encode_put") != null);
}
