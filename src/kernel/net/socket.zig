const events = @import("events");

pub const Role = enum { a, b };
pub const Socket = struct { ep: usize, role: Role, core: ?usize = null };

pub fn pair() ?struct { a: Socket, b: Socket } {
    if (events.endpoint_create()) |eid| {
        return .{ .a = .{ .ep = eid, .role = .a, .core = null }, .b = .{ .ep = eid, .role = .b, .core = null } };
    }
    return null;
}

pub fn send(s: *const Socket, data: []const u8) bool {
    if (s.core) |c| {
        const dir: u8 = if (s.role == .a) 0 else 1;
        return events.core_send(c, @as(u16, @intCast(s.ep)), dir, data);
    }
    return switch (s.role) { .a => events.endpoint_send_req(s.ep, data), .b => events.endpoint_send_rsp(s.ep, data) };
}

pub fn recv(s: *const Socket) ?[]const u8 {
    if (s.core) |c| {
        var ch: events.CoreMsgHdr = .{ .ep = 0, .dir = 0, .len = 0 };
        if (events.core_recv(c, &ch)) |b| {
            if (ch.ep == @as(u16, @intCast(s.ep))) {
                const expect: u8 = if (s.role == .a) 1 else 0;
                if (ch.dir == expect) return b;
            }
        }
        return null;
    }
    return switch (s.role) { .a => events.endpoint_recv_rsp(s.ep), .b => events.endpoint_recv_req(s.ep) };
}

pub fn close(s: *const Socket) bool { return events.endpoint_close(s.ep); }

const MaxNames = 8;
var names: [MaxNames][64]u8 = undefined;
var lens: [MaxNames]usize = undefined;
var eps: [MaxNames]usize = undefined;
var used: [MaxNames]bool = [_]bool{false} ** MaxNames;
var cores: [MaxNames]?usize = [_]?usize{null} ** MaxNames;

fn name_eq(a: []const u8, b: []const u8) bool { if (a.len != b.len) return false; var i: usize = 0; while (i < a.len) : (i += 1) if (a[i] != b[i]) return false; return true; }

pub fn listen(name: []const u8) ?usize {
    var i: usize = 0;
    while (i < MaxNames and used[i]) : (i += 1) {}
    if (i == MaxNames) return null;
    if (events.endpoint_create()) |eid| {
        var k: usize = 0; while (k < name.len and k < 64) : (k += 1) names[i][k] = name[k];
        lens[i] = if (name.len < 64) name.len else 64;
        eps[i] = eid;
        used[i] = true;
        return eid;
    }
    return null;
}

pub fn listen_on_core(name: []const u8, core: usize) ?usize {
    const eid = listen(name) orelse return null;
    var i: usize = 0;
    while (i < MaxNames) : (i += 1) {
        if (used[i]) {
            const n = names[i][0..lens[i]];
            if (name_eq(n, name)) { cores[i] = core; break; }
        }
    }
    return eid;
}

pub fn accept(name: []const u8) ?Socket {
    var i: usize = 0;
    while (i < MaxNames) : (i += 1) {
        if (used[i]) {
            const n = names[i][0..lens[i]];
            if (name_eq(n, name)) return .{ .ep = eps[i], .role = .a, .core = cores[i] };
        }
    }
    return null;
}

pub fn connect(name: []const u8) ?Socket {
    var i: usize = 0;
    while (i < MaxNames) : (i += 1) {
        if (used[i]) {
            const n = names[i][0..lens[i]];
            if (name_eq(n, name)) return .{ .ep = eps[i], .role = .b, .core = cores[i] };
        }
    }
    return null;
}

pub fn unlisten(name: []const u8) bool {
    var i: usize = 0;
    while (i < MaxNames) : (i += 1) {
        if (used[i]) {
            const n = names[i][0..lens[i]];
            if (name_eq(n, name)) { used[i] = false; cores[i] = null; return events.endpoint_close(eps[i]); }
        }
    }
    return false;
}

pub fn set_quota(name: []const u8, hi: u16, mid: u16, low: u16) bool {
    var i: usize = 0;
    while (i < MaxNames) : (i += 1) {
        if (used[i]) {
            const n = names[i][0..lens[i]];
            if (name_eq(n, name)) { events.set_ep_quota(eps[i], hi, mid, low); return true; }
        }
    }
    return false;
}

pub fn bind_core(s: *Socket, core: usize) void { s.core = core; }

pub fn send_all(s: *const Socket, bufs: [][]const u8) usize {
    return switch (s.role) { .a => events.endpoint_send_req_all(s.ep, bufs), .b => events.endpoint_send_rsp_all(s.ep, bufs) };
}

pub fn recv_batch(s: *const Socket, out: [][]const u8) usize {
    return switch (s.role) { .a => events.endpoint_recv_rsp_batch(s.ep, out), .b => events.endpoint_recv_req_batch(s.ep, out) };
}

pub fn send_msg(s: *const Socket, mid: u64, flags: u32, data: []const u8) bool {
    return switch (s.role) { .a => events.endpoint_send_req_msg(s.ep, mid, flags, data), .b => events.endpoint_send_rsp_msg(s.ep, mid, flags, data) };
}

pub fn recv_msg(s: *const Socket, out_hdr: *events.MsgHdr) ?[]const u8 {
    return switch (s.role) { .a => events.endpoint_recv_rsp_msg(s.ep, out_hdr), .b => events.endpoint_recv_req_msg(s.ep, out_hdr) };
}

pub fn send_msg_ex(s: *const Socket, mid: u64, flags: u32, deadline_ms: u32, err: u16, data: []const u8) bool {
    var hdr: extern struct { id: u64, flags: u32, len: u16, err: u16, deadline_ms: u32 } = .{ .id = mid, .flags = flags, .len = @as(u16, @intCast(data.len)), .err = err, .deadline_ms = deadline_ms };
    return if (s.role == .a) events.endpoint_send_req_msg(s.ep, hdr.id, hdr.flags, data) else events.endpoint_send_rsp_msg(s.ep, hdr.id, hdr.flags, data);
}

pub fn send_with_retry(s: *const Socket, mid: u64, flags: u32, data: []const u8, retries: u8) bool {
    var i: u8 = 0;
    while (i <= retries) : (i += 1) {
        if (send_msg(s, mid, flags, data)) return true;
    }
    return false;
}

pub fn recv_until(s: *const Socket, out_hdr: *events.MsgHdr, now_ms: u32) ?[]const u8 {
    const ev = @import("events");
    ev.set_now(now_ms);
    return switch (s.role) { .a => events.endpoint_recv_rsp_msg(s.ep, out_hdr), .b => events.endpoint_recv_req_msg(s.ep, out_hdr) };
}

pub fn send_with_retry_deadline(s: *const Socket, mid: u64, flags: u32, data: []const u8, until_ms: u32, step_ms: u32) bool {
    var now: u32 = 0;
    while (now <= until_ms) : (now += step_ms) {
        if (send_msg(s, mid, flags, data)) return true;
    }
    return false;
}