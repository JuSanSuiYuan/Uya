pub const Desc = struct { off: usize, len: usize };
pub const ShmQueue = struct {
    storage: []u8,
    descs: []Desc,
    cap: usize,
    head: usize,
    tail: usize,
    write_off: usize,

    pub fn init(storage: []u8, descs: []Desc) ShmQueue {
        return .{ .storage = storage, .descs = descs, .cap = descs.len, .head = 0, .tail = 0, .write_off = 0 };
    }

    pub fn pushBytes(self: *ShmQueue, data: []const u8) bool {
        const tail = atomic.loadUsize(&self.tail);
        const head = atomic.loadUsize(&self.head);
        const next = (tail + 1) % self.cap;
        if (next == head) return false;
        var i: usize = 0;
        var off = atomic.loadUsize(&self.write_off);
        const start_off = off;
        while (i < data.len) : (i += 1) {
            self.storage[off] = data[i];
            off = (off + 1) % self.storage.len;
        }
        self.descs[tail] = .{ .off = start_off, .len = data.len };
        atomic.storeUsize(&self.tail, next);
        atomic.storeUsize(&self.write_off, off);
        return true;
    }

    pub fn popBytes(self: *ShmQueue) ?[]const u8 {
        const head = atomic.loadUsize(&self.head);
        const tail = atomic.loadUsize(&self.tail);
        if (head == tail) return null;
        const d = self.descs[head];
        const next = (head + 1) % self.cap;
        atomic.storeUsize(&self.head, next);
        if (d.off + d.len <= self.storage.len) {
            return self.storage[d.off .. d.off + d.len];
        } else {
            return null;
        }
    }
};
const atomic = @import("compat_atomic");
