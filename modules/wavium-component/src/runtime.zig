const component = @import("component.zig");
pub const LinkedComponent = component.LinkedComponent;

/// Binds a linked component to a pluggable execution backend (e.g. the
/// `wavium-wasm` engine) without this module depending on that module
/// directly - callers supply function pointers operating on an opaque
/// instance handle, the same decoupling pattern used by the HAL driver
/// framework. This is what makes `wavium-component` a genuine "component
/// runtime" rather than just component/world metadata bookkeeping.
pub const RuntimeError = error{
    BackendInstantiateFailed,
    NotInstantiated,
};

pub const InstantiateFn = *const fn (linked: LinkedComponent) RuntimeError!*anyopaque;
pub const InvokeFn = *const fn (handle: *anyopaque, entry: []const u8, args: []const u8) RuntimeError!usize;
pub const DestroyFn = *const fn (handle: *anyopaque) void;

pub const ExecutionBackend = struct {
    instantiate: InstantiateFn,
    invoke: InvokeFn,
    destroy: DestroyFn,
};

pub const RunningComponent = struct {
    linked: LinkedComponent,
    handle: *anyopaque,
    backend: ExecutionBackend,
    alive: bool,

    pub fn invoke(self: *RunningComponent, entry: []const u8, args: []const u8) RuntimeError!usize {
        if (!self.alive) return error.NotInstantiated;
        return self.backend.invoke(self.handle, entry, args);
    }

    pub fn shutdown(self: *RunningComponent) void {
        if (!self.alive) return;
        self.backend.destroy(self.handle);
        self.alive = false;
    }
};

pub const ComponentRuntime = struct {
    backend: ExecutionBackend,

    pub fn init(backend: ExecutionBackend) ComponentRuntime {
        return .{ .backend = backend };
    }

    /// Instantiates `linked` against the configured backend, returning a
    /// `RunningComponent` handle callers use to invoke exported functions
    /// and eventually shut the instance down.
    pub fn start(self: ComponentRuntime, linked: LinkedComponent) RuntimeError!RunningComponent {
        const handle = try self.backend.instantiate(linked);
        return .{ .linked = linked, .handle = handle, .backend = self.backend, .alive = true };
    }
};
