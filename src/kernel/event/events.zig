const ring = @import("util_ring");
const shmq = @import("event_shmq");
const cap_types = @import("cap_types");
const cap_api = @import("cap_api");
const mpmc_mod = @import("util_mpmc");

pub const Event = struct { kind: u8, code: u32 };
var storage: [128]u64 = undefined;
pub var q = ring.SpscRing.init(storage[0..]);

pub fn init() void {}
pub fn push(kind: u8, code: u32) void { _ = q.push(((@as(u64, kind) << 32) | @as(u64, code))); }
pub fn pop() ?Event {
    if (q.pop()) |x| { return .{ .kind = @as(u8, @intCast(x >> 32)), .code = @as(u32, @intCast(x & 0xFFFF_FFFF)) }; }
    return null;
}

var shm_buf: [4096]u8 = undefined;
var shm_descs: [128]shmq.Desc = undefined;
var q_shm = shmq.ShmQueue.init(shm_buf[0..], shm_descs[0..]);
pub fn pushBytes(data: []const u8) bool { return q_shm.pushBytes(data); }
pub fn popBytes() ?[]const u8 { return q_shm.popBytes(); }

const MaxChan = 4;
var chan_buf: [MaxChan][4096]u8 = undefined;
var chan_descs: [MaxChan][128]shmq.Desc = undefined;
var chan_q: [MaxChan]shmq.ShmQueue = undefined;
var chan_used: [MaxChan]bool = [_]bool{false} ** MaxChan;

pub fn channel_init() void {
    var i: usize = 0;
    while (i < MaxChan) : (i += 1) {
        chan_q[i] = shmq.ShmQueue.init(chan_buf[i][0..], chan_descs[i][0..]);
        chan_used[i] = false;
    }
}

pub fn channel_create() ?usize {
    var i: usize = 0;
    while (i < MaxChan and chan_used[i]) : (i += 1) {}
    if (i == MaxChan) return null;
    chan_used[i] = true;
    return i;
}

pub fn channel_send(id: usize, data: []const u8) bool {
    if (id >= MaxChan or !chan_used[id]) return false;
    return chan_q[id].pushBytes(data);
}

pub fn channel_recv(id: usize) ?[]const u8 {
    if (id >= MaxChan or !chan_used[id]) return null;
    return chan_q[id].popBytes();
}

pub fn channel_close(id: usize) bool {
    if (id >= MaxChan or !chan_used[id]) return false;
    chan_used[id] = false;
    return true;
}

var per_core_buf: [8][4096]u8 = undefined;
var per_core_descs: [8][128]shmq.Desc = undefined;
var per_core_q: [8]shmq.ShmQueue = undefined;
var per_core_n: usize = 0;

pub fn per_core_init(n: usize) void {
    per_core_n = if (n > 8) 8 else n;
    var i: usize = 0;
    while (i < per_core_n) : (i += 1) {
        per_core_q[i] = shmq.ShmQueue.init(per_core_buf[i][0..], per_core_descs[i][0..]);
    }
}

pub fn per_core_send(core_id: usize, data: []const u8) bool {
    if (core_id >= per_core_n) return false;
    return per_core_q[core_id].pushBytes(data);
}

pub fn per_core_recv(core_id: usize) ?[]const u8 {
    if (core_id >= per_core_n) return null;
    const cap_epoch = @import("cap_epoch");
    cap_epoch.enter_core(core_id);
    defer cap_epoch.exit_core(core_id);
    return per_core_q[core_id].popBytes();
}

pub fn send_cap(core_id: usize, c: cap_types.Cap) bool {
    if (core_id >= per_core_n) return false;
    const s = cap_api.serialize(&c);
    const bytes: []const u8 = @as([*]const u8, @ptrCast(&s))[0..@sizeOf(cap_api.Serialized)];
    return per_core_q[core_id].pushBytes(bytes);
}

pub fn recv_cap(core_id: usize) ?cap_types.Cap {
    if (core_id >= per_core_n) return null;
    const sz = @sizeOf(cap_api.Serialized);
    if (per_core_q[core_id].popBytes()) |b| {
        if (b.len < sz) return null;
        const sptr: *const cap_api.Serialized = @ptrCast(@alignCast(b.ptr));
        return cap_api.deserialize(sptr);
    }
    return null;
}
var mpmc_rr: usize = 0;
pub fn mpmc_init(n: usize) void { mpmc_rr = 0; per_core_n = if (n > 8) 8 else n; }
pub fn mpmc_push(core_id: usize, data: []const u8) bool { return per_core_send(core_id, data); }
pub fn mpmc_pop() ?[]const u8 {
    if (per_core_n == 0) return null;
    var i: usize = 0;
    while (i < per_core_n) : (i += 1) {
        const idx = (mpmc_rr + i) % per_core_n;
        if (per_core_recv(idx)) |d| { mpmc_rr = (idx + 1) % per_core_n; return d; }
    }
    return null;
}

var m_nodes: [256]mpmc_mod.Node = undefined;
var m_head: u64 = 0;
var m_tail: u64 = 0;
var m_free: u64 = 0;
var mpmc_global: mpmc_mod.Mpmc = undefined;
pub fn mpmc_global_init() void { mpmc_global = mpmc_mod.Mpmc.init(m_nodes[0..], &m_head, &m_tail, &m_free); }
pub fn mpmc_global_push(data: []const u8) bool { return mpmc_global.enqueue(data); }
pub fn mpmc_global_pop() ?[]const u8 { return mpmc_global.dequeue(); }
pub fn per_core_broadcast(data: []const u8) void {
    var i: usize = 0;
    while (i < per_core_n) : (i += 1) {
        _ = per_core_q[i].pushBytes(data);
    }
}
