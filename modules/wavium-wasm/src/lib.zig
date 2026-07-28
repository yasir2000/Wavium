const std = @import("std");

pub const Backend = enum {
    interpreter,
    jit,
    aot,
};

pub const EngineConfig = struct {
    backend: Backend = .interpreter,
};

pub const WasmModule = struct {
    bytes_len: usize,
};

pub const InstanceOptions = struct {
    max_linear_memory_pages: u32 = 1,
};

pub const Instance = struct {
    id: u64,
    alive: bool,
    module: WasmModule,
};

pub const ExecResult = struct {
    bytes_returned: usize,
};

pub const WasmEngine = struct {
    config: EngineConfig,
    next_instance_id: u64,

    pub fn init(config: EngineConfig) WasmEngine {
        return .{ .config = config, .next_instance_id = 1 };
    }

    pub fn load(_: *WasmEngine, bytes: []const u8) !WasmModule {
        if (bytes.len < 4) return error.InvalidWasm;
        if (bytes[0] != 0x00 or bytes[1] != 0x61 or bytes[2] != 0x73 or bytes[3] != 0x6d) {
            return error.InvalidWasmMagic;
        }
        return .{ .bytes_len = bytes.len };
    }

    pub fn instantiate(self: *WasmEngine, module: WasmModule, opts: InstanceOptions) !Instance {
        if (opts.max_linear_memory_pages == 0) return error.InvalidInstanceOptions;

        const instance = Instance{
            .id = self.next_instance_id,
            .alive = true,
            .module = module,
        };
        self.next_instance_id += 1;
        return instance;
    }

    pub fn execute(_: *WasmEngine, inst: *const Instance, entry: []const u8, args: []const u8) !ExecResult {
        if (!inst.alive) return error.InstanceNotAlive;
        if (entry.len == 0) return error.InvalidEntryPoint;

        return .{ .bytes_returned = args.len };
    }

    pub fn destroy(_: *WasmEngine, inst: *Instance) void {
        inst.alive = false;
    }
};

test "default backend is interpreter" {
    const engine = WasmEngine.init(.{});
    try std.testing.expectEqual(Backend.interpreter, engine.config.backend);
}

test "engine load and lifecycle" {
    var engine = WasmEngine.init(.{});
    const wasm_magic = [_]u8{ 0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00 };

    const module = try engine.load(wasm_magic[0..]);
    var inst = try engine.instantiate(module, .{});

    const res = try engine.execute(&inst, "run", "abc");
    try std.testing.expectEqual(@as(usize, 3), res.bytes_returned);

    engine.destroy(&inst);
    try std.testing.expectError(error.InstanceNotAlive, engine.execute(&inst, "run", "x"));
}
