pub const Arena = struct {
    buffer: []u8,
    cursor: usize,

    pub fn init(buffer: []u8) Arena {
        return .{ .buffer = buffer, .cursor = 0 };
    }

    pub fn reset(self: *Arena) void {
        self.cursor = 0;
    }

    pub fn alloc(self: *Arena, n: usize, alignment: usize) ![]u8 {
        const aligned = alignForward(self.cursor, alignment);
        const end = aligned + n;
        if (end > self.buffer.len) return error.OutOfMemory;
        self.cursor = end;
        return self.buffer[aligned..end];
    }
};

fn alignForward(value: usize, alignment: usize) usize {
    const mask = alignment - 1;
    return (value + mask) & ~mask;
}
