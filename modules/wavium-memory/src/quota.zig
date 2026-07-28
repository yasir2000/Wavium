pub const Quota = struct {
    limit: usize,
    used: usize,

    pub fn init(limit: usize) Quota {
        return .{ .limit = limit, .used = 0 };
    }

    pub fn reserve(self: *Quota, n: usize) !void {
        if (self.used + n > self.limit) return error.QuotaExceeded;
        self.used += n;
    }

    pub fn release(self: *Quota, n: usize) void {
        if (n > self.used) {
            self.used = 0;
            return;
        }
        self.used -= n;
    }
};
