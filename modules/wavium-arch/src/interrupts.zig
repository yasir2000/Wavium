/// Runtime-facing interrupt-controller abstraction. Callers use
/// `mask()`/`unmask()`/`isMasked()` without knowing whether the underlying
/// architecture uses `cli`/`sti`, `msr daifset/daifclr`, or `sstatus` CSR
/// bits.
pub const InterruptController = struct {
    masked: bool,

    pub fn init() InterruptController {
        return .{ .masked = true };
    }

    pub fn mask(self: *InterruptController) void {
        self.masked = true;
    }

    pub fn unmask(self: *InterruptController) void {
        self.masked = false;
    }

    pub fn isMasked(self: InterruptController) bool {
        return self.masked;
    }
};
