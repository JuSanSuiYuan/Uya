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

const MaxEP = 8;
var ep_req_buf: [MaxEP][4096]u8 = undefined;
var ep_rsp_buf: [MaxEP][4096]u8 = undefined;
var ep_req_descs: [MaxEP][128]shmq.Desc = undefined;
var ep_rsp_descs: [MaxEP][128]shmq.Desc = undefined;
var ep_req_q: [MaxEP]shmq.ShmQueue = undefined;
var ep_rsp_q: [MaxEP]shmq.ShmQueue = undefined;
var ep_used: [MaxEP]bool = [_]bool{false} ** MaxEP;
var ep_req_hi_buf: [MaxEP][4096]u8 = undefined;
var ep_rsp_hi_buf: [MaxEP][4096]u8 = undefined;
var ep_req_hi_descs: [MaxEP][128]shmq.Desc = undefined;
var ep_rsp_hi_descs: [MaxEP][128]shmq.Desc = undefined;
var ep_req_q_hi: [MaxEP]shmq.ShmQueue = undefined;
var ep_rsp_q_hi: [MaxEP]shmq.ShmQueue = undefined;
var ep_req_mid_buf: [MaxEP][4096]u8 = undefined;
var ep_rsp_mid_buf: [MaxEP][4096]u8 = undefined;
var ep_req_mid_descs: [MaxEP][128]shmq.Desc = undefined;
var ep_rsp_mid_descs: [MaxEP][128]shmq.Desc = undefined;
var ep_req_q_mid: [MaxEP]shmq.ShmQueue = undefined;
var ep_rsp_q_mid: [MaxEP]shmq.ShmQueue = undefined;
var ep_quota_hi: [MaxEP]u16 = [_]u16{0} ** MaxEP;
var ep_quota_mid: [MaxEP]u16 = [_]u16{0} ** MaxEP;
var ep_quota_low: [MaxEP]u16 = [_]u16{0} ** MaxEP;
var ep_tokens_hi: [MaxEP]u16 = [_]u16{0} ** MaxEP;
var ep_tokens_mid: [MaxEP]u16 = [_]u16{0} ** MaxEP;
var ep_tokens_low: [MaxEP]u16 = [_]u16{0} ** MaxEP;
pub const MsgHdr = extern struct { id: u64, flags: u32, len: u16, err: u16, deadline_ms: u32 };
var now_ms: u32 = 0;
pub fn set_now(ms: u32) void { now_ms = ms; }

pub const CoreMsgHdr = extern struct { ep: u16, dir: u8, len: u16 };

pub fn core_send(core: usize, ep: u16, dir: u8, data: []const u8) bool {
    if (core >= per_core_n) return false;
    var hdr: CoreMsgHdr = .{ .ep = ep, .dir = dir, .len = @as(u16, @intCast(data.len)) };
    var buf: [512]u8 = undefined;
    const hbytes: []const u8 = @as([*]const u8, @ptrCast(&hdr))[0..@sizeOf(CoreMsgHdr)];
    var i: usize = 0; while (i < hbytes.len) : (i += 1) buf[i] = hbytes[i];
    var j: usize = 0; while (j < data.len) : (j += 1) buf[hbytes.len + j] = data[j];
    return per_core_q[core].pushBytes(buf[0 .. hbytes.len + data.len]);
}

pub fn core_recv(core: usize, out_hdr: *CoreMsgHdr) ?[]const u8 {
    if (core >= per_core_n) return null;
    if (per_core_q[core].popBytes()) |b| {
        if (b.len < @sizeOf(CoreMsgHdr)) return null;
        const hp: *const CoreMsgHdr = @ptrCast(@alignCast(b.ptr));
        out_hdr.* = hp.*;
        const need: usize = @sizeOf(CoreMsgHdr) + @as(usize, out_hdr.len);
        if (b.len < need) return null;
        return b[@sizeOf(CoreMsgHdr) .. @sizeOf(CoreMsgHdr) + @as(usize, out_hdr.len)];
    }
    return null;
}

pub fn endpoint_create() ?usize {
    var i: usize = 0;
    while (i < MaxEP and ep_used[i]) : (i += 1) {}
    if (i == MaxEP) return null;
    ep_req_q[i] = shmq.ShmQueue.init(ep_req_buf[i][0..], ep_req_descs[i][0..]);
    ep_rsp_q[i] = shmq.ShmQueue.init(ep_rsp_buf[i][0..], ep_rsp_descs[i][0..]);
    ep_req_q_hi[i] = shmq.ShmQueue.init(ep_req_hi_buf[i][0..], ep_req_hi_descs[i][0..]);
    ep_rsp_q_hi[i] = shmq.ShmQueue.init(ep_rsp_hi_buf[i][0..], ep_rsp_hi_descs[i][0..]);
    ep_req_q_mid[i] = shmq.ShmQueue.init(ep_req_mid_buf[i][0..], ep_req_mid_descs[i][0..]);
    ep_rsp_q_mid[i] = shmq.ShmQueue.init(ep_rsp_mid_buf[i][0..], ep_rsp_mid_descs[i][0..]);
    ep_used[i] = true;
    return i;
}

pub fn endpoint_close(id: usize) bool {
    if (id >= MaxEP or !ep_used[id]) return false;
    ep_used[id] = false;
    return true;
}

pub fn set_ep_quota(id: usize, hi: u16, mid: u16, low: u16) void {
    if (id >= MaxEP or !ep_used[id]) return;
    ep_quota_hi[id] = hi;
    ep_quota_mid[id] = mid;
    ep_quota_low[id] = low;
    ep_tokens_hi[id] = hi;
    ep_tokens_mid[id] = mid;
    ep_tokens_low[id] = low;
}

pub fn get_ep_backpressure(id: usize) struct { hi: u16, mid: u16, low: u16 } {
    if (id >= MaxEP or !ep_used[id]) return .{ .hi = 0, .mid = 0, .low = 0 };
    return .{ .hi = ep_tokens_hi[id], .mid = ep_tokens_mid[id], .low = ep_tokens_low[id] };
}

pub fn endpoint_send_req(id: usize, data: []const u8) bool {
    if (id >= MaxEP or !ep_used[id]) return false;
    return ep_req_q[id].pushBytes(data);
}

pub fn endpoint_recv_req(id: usize) ?[]const u8 {
    if (id >= MaxEP or !ep_used[id]) return null;
    if (ep_req_q_hi[id].popBytes()) |b| return b;
    if (ep_req_q_mid[id].popBytes()) |bm| return bm;
    return ep_req_q[id].popBytes();
}

pub fn endpoint_send_rsp(id: usize, data: []const u8) bool {
    if (id >= MaxEP or !ep_used[id]) return false;
    return ep_rsp_q[id].pushBytes(data);
}

pub fn endpoint_recv_rsp(id: usize) ?[]const u8 {
    if (id >= MaxEP or !ep_used[id]) return null;
    if (ep_rsp_q_hi[id].popBytes()) |b| return b;
    if (ep_rsp_q_mid[id].popBytes()) |bm| return bm;
    return ep_rsp_q[id].popBytes();
}

pub fn endpoint_send_req_all(id: usize, bufs: [][]const u8) usize {
    if (id >= MaxEP or !ep_used[id]) return 0;
    var sent: usize = 0;
    var i: usize = 0;
    while (i < bufs.len) : (i += 1) {
        if (ep_req_q[id].pushBytes(bufs[i])) sent += 1 else break;
    }
    return sent;
}

pub fn endpoint_send_rsp_all(id: usize, bufs: [][]const u8) usize {
    if (id >= MaxEP or !ep_used[id]) return 0;
    var sent: usize = 0;
    var i: usize = 0;
    while (i < bufs.len) : (i += 1) {
        if (ep_rsp_q[id].pushBytes(bufs[i])) sent += 1 else break;
    }
    return sent;
}

pub fn endpoint_recv_req_batch(id: usize, out: [][]const u8) usize {
    if (id >= MaxEP or !ep_used[id]) return 0;
    var got: usize = 0;
    while (got < out.len) : (got += 1) {
        if (ep_req_q_hi[id].popBytes()) |bh| { out[got] = bh; }
        else if (ep_req_q_mid[id].popBytes()) |bm| { out[got] = bm; }
        else if (ep_req_q[id].popBytes()) |b| { out[got] = b; }
        else { break; }
    }
    return got;
}

pub fn endpoint_recv_rsp_batch(id: usize, out: [][]const u8) usize {
    if (id >= MaxEP or !ep_used[id]) return 0;
    var got: usize = 0;
    while (got < out.len) : (got += 1) {
        if (ep_rsp_q_hi[id].popBytes()) |bh| { out[got] = bh; }
        else if (ep_rsp_q_mid[id].popBytes()) |bm| { out[got] = bm; }
        else if (ep_rsp_q[id].popBytes()) |b| { out[got] = b; }
        else { break; }
    }
    return got;
}

pub fn endpoint_send_cap_req(id: usize, c: cap_types.Cap) bool {
    if (id >= MaxEP or !ep_used[id]) return false;
    const s = cap_api.serialize(&c);
    const bytes: []const u8 = @as([*]const u8, @ptrCast(&s))[0..@sizeOf(cap_api.Serialized)];
    return ep_req_q[id].pushBytes(bytes);
}

pub fn endpoint_recv_cap_req(id: usize) ?cap_types.Cap {
    if (id >= MaxEP or !ep_used[id]) return null;
    const sz = @sizeOf(cap_api.Serialized);
    if (ep_req_q[id].popBytes()) |b| {
        if (b.len < sz) return null;
        const sptr: *const cap_api.Serialized = @ptrCast(@alignCast(b.ptr));
        return cap_api.deserialize(sptr);
    }
    return null;
}

pub fn endpoint_send_cap_rsp(id: usize, c: cap_types.Cap) bool {
    if (id >= MaxEP or !ep_used[id]) return false;
    const s = cap_api.serialize(&c);
    const bytes: []const u8 = @as([*]const u8, @ptrCast(&s))[0..@sizeOf(cap_api.Serialized)];
    return ep_rsp_q[id].pushBytes(bytes);
}

pub fn endpoint_recv_cap_rsp(id: usize) ?cap_types.Cap {
    if (id >= MaxEP or !ep_used[id]) return null;
    const sz = @sizeOf(cap_api.Serialized);
    if (ep_rsp_q[id].popBytes()) |b| {
        if (b.len < sz) return null;
        const sptr: *const cap_api.Serialized = @ptrCast(@alignCast(b.ptr));
        return cap_api.deserialize(sptr);
    }
    return null;
}

pub fn endpoint_send_req_msg(id: usize, mid: u64, flags: u32, data: []const u8) bool {
    if (id >= MaxEP or !ep_used[id]) return false;
    if (data.len + @sizeOf(MsgHdr) > 512) return false;
    var hdr: MsgHdr = .{ .id = mid, .flags = flags, .len = @as(u16, @intCast(data.len)), .err = 0, .deadline_ms = 0 };
    var buf: [512]u8 = undefined;
    const hbytes: []const u8 = @as([*]const u8, @ptrCast(&hdr))[0..@sizeOf(MsgHdr)];
    var i: usize = 0; while (i < hbytes.len) : (i += 1) buf[i] = hbytes[i];
    var j: usize = 0; while (j < data.len) : (j += 1) buf[hbytes.len + j] = data[j];
    const pr = flags & 3;
    switch (pr) {
        1 => {
            if (ep_quota_hi[id] != 0 and ep_tokens_hi[id] == 0) return false;
            const ok = ep_req_q_hi[id].pushBytes(buf[0 .. hbytes.len + data.len]);
            if (ok and ep_quota_hi[id] != 0) ep_tokens_hi[id] -= 1;
            return ok;
        },
        2 => {
            if (ep_quota_mid[id] != 0 and ep_tokens_mid[id] == 0) return false;
            const ok = ep_req_q_mid[id].pushBytes(buf[0 .. hbytes.len + data.len]);
            if (ok and ep_quota_mid[id] != 0) ep_tokens_mid[id] -= 1;
            return ok;
        },
        else => {
            if (ep_quota_low[id] != 0 and ep_tokens_low[id] == 0) return false;
            const ok = ep_req_q[id].pushBytes(buf[0 .. hbytes.len + data.len]);
            if (ok and ep_quota_low[id] != 0) ep_tokens_low[id] -= 1;
            return ok;
        },
    }
}

pub fn endpoint_recv_req_msg(id: usize, out_hdr: *MsgHdr) ?[]const u8 {
    if (id >= MaxEP or !ep_used[id]) return null;
    if (ep_req_q_hi[id].popBytes()) |b| {
        if (b.len < @sizeOf(MsgHdr)) return null;
    const hp: *const MsgHdr = @ptrCast(@alignCast(b.ptr));
    out_hdr.* = hp.*;
        const need: usize = @sizeOf(MsgHdr) + @as(usize, out_hdr.len);
        if (b.len < need) return null;
        if (out_hdr.deadline_ms != 0 and out_hdr.deadline_ms < now_ms) {
            var tmp: [512]u8 = undefined;
            var i: usize = 0; while (i < need) : (i += 1) tmp[i] = b[i];
            _ = ep_req_q[id].pushBytes(tmp[0..need]);
            return null;
        }
        if (ep_quota_hi[id] != 0) ep_tokens_hi[id] += 1;
        return b[@sizeOf(MsgHdr) .. @sizeOf(MsgHdr) + @as(usize, out_hdr.len)];
    }
    if (ep_req_q_mid[id].popBytes()) |b2| {
        if (b2.len < @sizeOf(MsgHdr)) return null;
        const hp2: *const MsgHdr = @ptrCast(@alignCast(b2.ptr));
        out_hdr.* = hp2.*;
        const need2: usize = @sizeOf(MsgHdr) + @as(usize, out_hdr.len);
        if (b2.len < need2) return null;
        if (out_hdr.deadline_ms != 0 and out_hdr.deadline_ms < now_ms) {
            var tmp2: [512]u8 = undefined;
            var j: usize = 0; while (j < need2) : (j += 1) tmp2[j] = b2[j];
            _ = ep_req_q[id].pushBytes(tmp2[0..need2]);
            return null;
        }
        if (ep_quota_mid[id] != 0) ep_tokens_mid[id] += 1;
        return b2[@sizeOf(MsgHdr) .. @sizeOf(MsgHdr) + @as(usize, out_hdr.len)];
    }
    if (ep_req_q[id].popBytes()) |b3| {
        if (b3.len < @sizeOf(MsgHdr)) return null;
        const hp3: *const MsgHdr = @ptrCast(@alignCast(b3.ptr));
        out_hdr.* = hp3.*;
        const need3: usize = @sizeOf(MsgHdr) + @as(usize, out_hdr.len);
        if (b3.len < need3) return null;
        if (ep_quota_low[id] != 0) ep_tokens_low[id] += 1;
        return b3[@sizeOf(MsgHdr) .. @sizeOf(MsgHdr) + @as(usize, out_hdr.len)];
    }
    return null;
}

pub fn endpoint_send_rsp_msg(id: usize, mid: u64, flags: u32, data: []const u8) bool {
    if (id >= MaxEP or !ep_used[id]) return false;
    if (data.len + @sizeOf(MsgHdr) > 512) return false;
    var hdr: MsgHdr = .{ .id = mid, .flags = flags, .len = @as(u16, @intCast(data.len)), .err = 0, .deadline_ms = 0 };
    var buf: [512]u8 = undefined;
    const hbytes: []const u8 = @as([*]const u8, @ptrCast(&hdr))[0..@sizeOf(MsgHdr)];
    var i: usize = 0; while (i < hbytes.len) : (i += 1) buf[i] = hbytes[i];
    var j: usize = 0; while (j < data.len) : (j += 1) buf[hbytes.len + j] = data[j];
    const pr = flags & 3;
    switch (pr) {
        1 => {
            if (ep_quota_hi[id] != 0 and ep_tokens_hi[id] == 0) return false;
            const ok = ep_rsp_q_hi[id].pushBytes(buf[0 .. hbytes.len + data.len]);
            if (ok and ep_quota_hi[id] != 0) ep_tokens_hi[id] -= 1;
            return ok;
        },
        2 => {
            if (ep_quota_mid[id] != 0 and ep_tokens_mid[id] == 0) return false;
            const ok = ep_rsp_q_mid[id].pushBytes(buf[0 .. hbytes.len + data.len]);
            if (ok and ep_quota_mid[id] != 0) ep_tokens_mid[id] -= 1;
            return ok;
        },
        else => {
            if (ep_quota_low[id] != 0 and ep_tokens_low[id] == 0) return false;
            const ok = ep_rsp_q[id].pushBytes(buf[0 .. hbytes.len + data.len]);
            if (ok and ep_quota_low[id] != 0) ep_tokens_low[id] -= 1;
            return ok;
        },
    }
}

pub fn endpoint_recv_rsp_msg(id: usize, out_hdr: *MsgHdr) ?[]const u8 {
    if (id >= MaxEP or !ep_used[id]) return null;
    if (ep_rsp_q_hi[id].popBytes()) |b| {
        if (b.len < @sizeOf(MsgHdr)) return null;
        const hp: *const MsgHdr = @ptrCast(@alignCast(b.ptr));
        out_hdr.* = hp.*;
        const need: usize = @sizeOf(MsgHdr) + @as(usize, out_hdr.len);
        if (b.len < need) return null;
        if (out_hdr.deadline_ms != 0 and out_hdr.deadline_ms < now_ms) {
            var tmp: [512]u8 = undefined;
            var i: usize = 0; while (i < need) : (i += 1) tmp[i] = b[i];
            _ = ep_rsp_q[id].pushBytes(tmp[0..need]);
            return null;
        }
        if (ep_quota_hi[id] != 0) ep_tokens_hi[id] += 1;
        return b[@sizeOf(MsgHdr) .. @sizeOf(MsgHdr) + @as(usize, out_hdr.len)];
    }
    if (ep_rsp_q_mid[id].popBytes()) |b2| {
        if (b2.len < @sizeOf(MsgHdr)) return null;
        const hp2: *const MsgHdr = @ptrCast(@alignCast(b2.ptr));
        out_hdr.* = hp2.*;
        const need2: usize = @sizeOf(MsgHdr) + @as(usize, out_hdr.len);
        if (b2.len < need2) return null;
        if (out_hdr.deadline_ms != 0 and out_hdr.deadline_ms < now_ms) {
            var tmp2: [512]u8 = undefined;
            var j: usize = 0; while (j < need2) : (j += 1) tmp2[j] = b2[j];
            _ = ep_rsp_q[id].pushBytes(tmp2[0..need2]);
            return null;
        }
        if (ep_quota_mid[id] != 0) ep_tokens_mid[id] += 1;
        return b2[@sizeOf(MsgHdr) .. @sizeOf(MsgHdr) + @as(usize, out_hdr.len)];
    }
    if (ep_rsp_q[id].popBytes()) |b3| {
        if (b3.len < @sizeOf(MsgHdr)) return null;
        const hp3: *const MsgHdr = @ptrCast(@alignCast(b3.ptr));
        out_hdr.* = hp3.*;
        const need3: usize = @sizeOf(MsgHdr) + @as(usize, out_hdr.len);
        if (b3.len < need3) return null;
        if (ep_quota_low[id] != 0) ep_tokens_low[id] += 1;
        return b3[@sizeOf(MsgHdr) .. @sizeOf(MsgHdr) + @as(usize, out_hdr.len)];
    }
    return null;
}
