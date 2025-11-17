pub const SpscRing = struct {
    buf: []u64,
    cap: usize,
    write_idx: usize,
    read_idx: usize,

    pub fn init(storage: []u64) SpscRing {
        return .{ .buf = storage, .cap = storage.len, .write_idx = 0, .read_idx = 0 };
    }

    pub fn push(self: *SpscRing, v: u64) bool {
        const w = atomic.loadUsize(&self.write_idx);
        const next = (w + 1) % self.cap;
        const r = atomic.loadUsize(&self.read_idx);
        if (next == r) return false;
        self.buf[w] = v;
        atomic.storeUsize(&self.write_idx, next);
        return true;
    }

    pub fn pop(self: *SpscRing) ?u64 {
        const r = atomic.loadUsize(&self.read_idx);
        const w = atomic.loadUsize(&self.write_idx);
        if (r == w) return null;
        const v = self.buf[r];
        const next = (r + 1) % self.cap;
        atomic.storeUsize(&self.read_idx, next);
        return v;
    }
};
const atomic = @import("compat_atomic");
