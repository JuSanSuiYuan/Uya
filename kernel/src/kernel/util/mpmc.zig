const atomic = @import("compat_atomic");
const cap_epoch = @import("cap_epoch");

pub const Node = struct { next: i32, len: u16, buf: [64]u8 };
const Ret = struct { idx: i32, epoch: u32 };
pub const Mpmc = struct {
    nodes: []Node,
    head: *volatile u64,
    tail: *volatile u64,
    free: *volatile u64,
    retire_buf: [256]Ret = [_]Ret{.{ .idx = -1, .epoch = 0 }} ** 256,
    retire_len: usize = 0,
    pub fn init(storage: []Node, head_ptr: *volatile u64, tail_ptr: *volatile u64, free_ptr: *volatile u64) Mpmc {
        head_ptr.* = pack(0, 0);
        tail_ptr.* = pack(0, 0);
        free_ptr.* = pack(1, 0);
        var i: usize = 1;
        while (i + 1 < storage.len) : (i += 1) storage[i].next = @as(i32, @intCast(i + 1));
        storage[storage.len - 1].next = -1;
        storage[0].next = -1;
        storage[0].len = 0;
        return .{ .nodes = storage, .head = head_ptr, .tail = tail_ptr, .free = free_ptr };
    }
    fn pack(idx: i32, ver: u32) u64 {
        const iv: u32 = @bitCast(idx);
        return (@as(u64, ver) << 32) | @as(u64, iv);
    }
    fn unpack(v: u64) struct { idx: i32, ver: u32 } {
        const iv: u32 = @as(u32, @intCast(v & 0xFFFF_FFFF));
        const idx: i32 = @bitCast(iv);
        const ver: u32 = @as(u32, @intCast(v >> 32));
        return .{ .idx = idx, .ver = ver };
    }
    fn drain_reclaimed(self: *Mpmc) void {
        var i: usize = 0;
        while (i < self.retire_len) : (i += 1) {
            const r = self.retire_buf[i];
            if (r.idx == -1) continue;
            if (cap_epoch.is_reclaimable(r.epoch)) {
                self.push_free(r.idx);
                self.retire_buf[i].idx = -1;
            }
        }
    }
    fn retire(self: *Mpmc, idx: i32) void {
        if (self.retire_len < self.retire_buf.len) {
            self.retire_buf[self.retire_len] = .{ .idx = idx, .epoch = cap_epoch.enter().epoch };
            self.retire_len += 1;
        } else {
            self.push_free(idx);
        }
    }
    fn pop_free(self: *Mpmc) ?i32 {
        while (true) {
            const fp = unpack(self.free.*);
            const cur = fp.idx;
            if (cur == -1) return null;
            const nxt = self.nodes[@as(usize, @intCast(cur))].next;
            const oldp = pack(cur, fp.ver);
            const newp = pack(nxt, fp.ver +% 1);
            if (atomic.casU64(self.free, oldp, newp)) return cur;
        }
    }
    fn push_free(self: *Mpmc, idx: i32) void {
        while (true) {
            const fp = unpack(self.free.*);
            const cur = fp.idx;
            self.nodes[@as(usize, @intCast(idx))].next = cur;
            const oldp = pack(cur, fp.ver);
            const newp = pack(idx, fp.ver +% 1);
            if (atomic.casU64(self.free, oldp, newp)) return;
        }
    }
    pub fn enqueue(self: *Mpmc, data: []const u8) bool {
        self.drain_reclaimed();
        const n_opt = self.pop_free();
        if (n_opt == null) return false;
        const idx = n_opt.?;
        var k: usize = 0;
        const wlen: u16 = @as(u16, @intCast(if (data.len > 64) 64 else data.len));
        while (k < wlen) : (k += 1) self.nodes[@as(usize, @intCast(idx))].buf[k] = data[k];
        self.nodes[@as(usize, @intCast(idx))].len = wlen;
        self.nodes[@as(usize, @intCast(idx))].next = -1;
        while (true) {
            const tp = unpack(self.tail.*);
            const tail_idx = tp.idx;
            const tail_next = self.nodes[@as(usize, @intCast(tail_idx))].next;
            if (tail_next == -1) {
                if (atomic.casI32(&self.nodes[@as(usize, @intCast(tail_idx))].next, -1, idx)) {
                    const oldp = pack(tail_idx, tp.ver);
                    const newp = pack(idx, tp.ver +% 1);
                    _ = atomic.casU64(self.tail, oldp, newp);
                    return true;
                }
            } else {
                const oldp = pack(tail_idx, tp.ver);
                const newp = pack(tail_next, tp.ver +% 1);
                _ = atomic.casU64(self.tail, oldp, newp);
            }
        }
    }
    pub fn dequeue(self: *Mpmc) ?[]const u8 {
        self.drain_reclaimed();
        const tok = cap_epoch.enter();
        defer cap_epoch.exit(tok);
        while (true) {
            const hp = unpack(self.head.*);
            const head_idx = hp.idx;
            const head_next = self.nodes[@as(usize, @intCast(head_idx))].next;
            if (head_next == -1) return null;
            const oldp = pack(head_idx, hp.ver);
            const newp = pack(head_next, hp.ver +% 1);
            if (atomic.casU64(self.head, oldp, newp)) {
                const len = self.nodes[@as(usize, @intCast(head_next))].len;
                const off: usize = 0;
                const ret = self.nodes[@as(usize, @intCast(head_next))].buf[off .. off + len];
                self.retire(head_idx);
                return ret;
            }
        }
    }
};