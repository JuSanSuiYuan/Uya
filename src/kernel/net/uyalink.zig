const events = @import("events");
const vfs = @import("fs_vfs");
const percpu = @import("arch/x86_64/percpu.zig");

pub const Attr = struct { kind: u16, val: []const u8 };

fn u16_from_le(b: []const u8, i: usize) u16 {
    return (@as(u16, b[i]) | (@as(u16, b[i + 1]) << 8));
}

fn put_u16_le(b: []u8, i: usize, v: u16) void {
    b[i] = @as(u8, @intCast(v & 0xFF));
    b[i + 1] = @as(u8, @intCast((v >> 8) & 0xFF));
}

fn align4(n: usize) usize { return (n + 3) & ~@as(usize, 3); }

pub fn make_type(family: u16, op: u16) u64 {
    return ((@as(u64, family) << 32) | @as(u64, op));
}

pub fn encode_attrs(attrs: []const Attr, buf: []u8) usize {
    var pos: usize = 0;
    var i: usize = 0;
    while (i < attrs.len) : (i += 1) {
        const a = attrs[i];
        const need = align4(4 + a.val.len);
        if (pos + need > buf.len) break;
        put_u16_le(buf[0..], pos, a.kind);
        put_u16_le(buf[0..], pos + 2, @as(u16, @intCast(a.val.len)));
        @memcpy(buf[pos + 4 .. pos + 4 + a.val.len], a.val);
        if (need > 4 + a.val.len) {
            @memset(buf[pos + 4 + a.val.len .. pos + need], 0);
        }
        pos += need;
    }
    return pos;
}

fn append_attr(buf: []u8, pos: usize, a: Attr) usize {
    const need = align4(4 + a.val.len);
    if (pos + need > buf.len) return pos;
    put_u16_le(buf[0..], pos, a.kind);
    put_u16_le(buf[0..], pos + 2, @as(u16, @intCast(a.val.len)));
    @memcpy(buf[pos + 4 .. pos + 4 + a.val.len], a.val);
    if (need > 4 + a.val.len) {
        @memset(buf[pos + 4 + a.val.len .. pos + need], 0);
    }
    return pos + need;
}

pub fn decode_attrs(b: []const u8, out: []Attr) usize {
    var pos: usize = 0;
    var got: usize = 0;
    while (pos + 4 <= b.len and got < out.len) {
        const kind = u16_from_le(b, pos);
        const len = u16_from_le(b, pos + 2);
        if (pos + 4 + @as(usize, len) > b.len) break;
        out[got] = .{ .kind = kind, .val = b[pos + 4 .. pos + 4 + @as(usize, len)] };
        got += 1;
        pos += align4(4 + @as(usize, len));
    }
    return got;
}

fn find_attr(attrs: []const Attr, kind: u16) ?[]const u8 {
    var i: usize = 0;
    while (i < attrs.len) : (i += 1) {
        if (attrs[i].kind == kind) return attrs[i].val;
    }
    return null;
}

pub const Family = enum(u16) { vfs = 1, registry = 2, process = 3, gc = 4, ai = 5, drv = 6 };
pub const Op = enum(u16) { get = 1, list = 2, set = 3, subscribe = 4, install = 5, verify = 6, rollback = 7 };
pub const AttrKind = enum(u16) { path = 1, dir = 2, name = 3, is_dir = 4, key = 5, value = 6, errcode = 7, core_id = 8, tasks = 9, ticks = 10, offset = 11, limit = 12, gc_step = 13, gc_pause = 14, prompt = 15, lang = 16, code = 17, ai_model = 18, os_src = 19, dev_id = 20, src = 21, patched = 22, status = 23, version = 24, root = 25, log = 26 };
pub const FLAG_MULTI: u32 = 1 << 8;
pub const FLAG_DONE: u32 = 1 << 9;
pub const FLAG_ACK: u32 = 1 << 10;
pub const ERR_NOT_FOUND: u8 = 1;
pub const ERR_DENIED: u8 = 2;
pub const ERR_OVERFLOW: u8 = 3;

var proc_sub_eps: [8]usize = [_]usize{0} ** 8;
var proc_sub_used: [8]bool = [_]bool{false} ** 8;
pub fn proc_subscribe(ep: usize) bool {
    var i: usize = 0;
    while (i < proc_sub_used.len and proc_sub_used[i]) : (i += 1) {}
    if (i == proc_sub_used.len) return false;
    proc_sub_used[i] = true;
    proc_sub_eps[i] = ep;
    return true;
}
pub fn proc_unsubscribe(ep: usize) bool {
    var i: usize = 0;
    while (i < proc_sub_used.len) : (i += 1) {
        if (proc_sub_used[i] and proc_sub_eps[i] == ep) { proc_sub_used[i] = false; return true; }
    }
    return false;
}
pub fn proc_notify_core(core_id: usize) void {
    var pc = percpu.get(core_id).*;
    var tlv: [64]u8 = undefined;
    var pos: usize = 0;
    var cidb: [2]u8 = undefined; cidb[0] = @as(u8, @intCast(core_id & 0xFF)); cidb[1] = @as(u8, @intCast((core_id >> 8) & 0xFF));
    pos = append_attr(tlv[0..], pos, .{ .kind = @intFromEnum(AttrKind.core_id), .val = cidb[0..] });
    var tb: [8]u8 = undefined; var ti: usize = 0; var tp: u64 = pc.tasks_processed; while (ti < 8) : (ti += 1) { tb[ti] = @as(u8, @intCast((tp >> (ti * 8)) & 0xFF)); }
    pos = append_attr(tlv[0..], pos, .{ .kind = @intFromEnum(AttrKind.tasks), .val = tb[0..] });
    var kb: [8]u8 = undefined; var ki: usize = 0; var tk: u64 = pc.ticks; while (ki < 8) : (ki += 1) { kb[ki] = @as(u8, @intCast((tk >> (ki * 8)) & 0xFF)); }
    pos = append_attr(tlv[0..], pos, .{ .kind = @intFromEnum(AttrKind.ticks), .val = kb[0..] });
    var i: usize = 0;
    while (i < proc_sub_used.len) : (i += 1) {
        if (proc_sub_used[i]) { _ = events.endpoint_send_rsp_msg(proc_sub_eps[i], make_type(@intFromEnum(Family.process), @intFromEnum(Op.subscribe)), 0, tlv[0..pos]); }
    }
}
pub const ERR_NOT_FOUND: u8 = 1;
pub const ERR_DENIED: u8 = 2;
pub const ERR_OVERFLOW: u8 = 3;

pub fn send_req(ep: usize, family: u16, op: u16, attrs: []const Attr, flags: u32) bool {
    var buf: [512]u8 = undefined;
    const n = encode_attrs(attrs, buf[0..]);
    return events.endpoint_send_req_msg(ep, make_type(family, op), flags, buf[0..n]);
}
pub fn is_ack(flags: u32) bool { return (flags & FLAG_ACK) != 0; }
pub fn encode_err(buf: []u8, code: u8) usize { var a: Attr = .{ .kind = @intFromEnum(AttrKind.errcode), .val = &[_]u8{ code } }; return encode_attrs(&[_]Attr{ a }, buf); }
pub fn decode_err(b: []const u8) ?u8 { var ab: [2]Attr = undefined; const g = decode_attrs(b, ab[0..]); var i: usize = 0; while (i < g) : (i += 1) { if (ab[i].kind == @intFromEnum(AttrKind.errcode) and ab[i].val.len >= 1) return ab[i].val[0]; } return null; }

pub fn recv_req(ep: usize, out_hdr: *events.MsgHdr) ?[]const u8 {
    return events.endpoint_recv_req_msg(ep, out_hdr);
}

pub fn send_rsp(ep: usize, mid: u64, flags: u32, data: []const u8) bool {
    return events.endpoint_send_rsp_msg(ep, mid, flags, data);
}

pub fn handle_once(ep: usize) bool {
    var hdr: events.MsgHdr = .{ .id = 0, .flags = 0, .len = 0, .err = 0, .deadline_ms = 0 };
    if (events.endpoint_recv_req_msg(ep, &hdr)) |payload| {
        const family: u16 = @as(u16, @intCast(hdr.id >> 32));
        const op: u16 = @as(u16, @intCast(hdr.id & 0xFFFF));
        var attrs_buf: [8]Attr = undefined;
        const got = decode_attrs(payload, attrs_buf[0..]);
        const attrs = attrs_buf[0..got];
        if (family == @intFromEnum(Family.vfs) and op == @intFromEnum(Op.get)) {
            if (find_attr(attrs, @intFromEnum(AttrKind.path))) |p| {
                if (vfs.UyaFS.read(p)) |d| {
                    _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags, d);
                    return true;
                } else {
                    var empty: [0]u8 = {};
                    _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags, empty[0..]);
                    return false;
                }
            } else {
                var empty2: [0]u8 = {};
                _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags, empty2[0..]);
                return false;
            }
        } else if (family == @intFromEnum(Family.vfs) and op == @intFromEnum(Op.list)) {
            var dirbuf: [32]vfs.UyaFS.DirEntry = undefined;
            const dirok = find_attr(attrs, @intFromEnum(AttrKind.dir)) orelse "/";
            const n = vfs.UyaFS.list(dirok, dirbuf[0..]);
            var outb: [512]u8 = undefined;
            var pos: usize = 0;
            var off: usize = 0;
            var lim: usize = n;
            if (find_attr(attrs, @intFromEnum(AttrKind.offset))) |ao| { if (ao.len >= 2) { off = @as(usize, ao[0]) | (@as(usize, ao[1]) << 8); } }
            if (find_attr(attrs, @intFromEnum(AttrKind.limit))) |al| { if (al.len >= 2) { lim = @as(usize, al[0]) | (@as(usize, al[1]) << 8); } }
            var i: usize = 0;
            var emitted: usize = 0;
            while (i < n and emitted < lim) : (i += 1) {
                var nm_attr: Attr = .{ .kind = @intFromEnum(AttrKind.name), .val = dirbuf[i].name };
                var id_attr_buf: [1]u8 = undefined;
                id_attr_buf[0] = if (dirbuf[i].is_dir) 1 else 0;
                var id_attr: Attr = .{ .kind = @intFromEnum(AttrKind.is_dir), .val = id_attr_buf[0..] };
                if (i < off) continue;
                var next = append_attr(outb[0..], pos, nm_attr);
                if (next == pos) {
                    _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags | FLAG_MULTI, outb[0..pos]);
                    pos = 0;
                    next = append_attr(outb[0..], pos, nm_attr);
                }
                pos = append_attr(outb[0..], next, id_attr);
                if (pos + 8 > outb.len) {
                    _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags | FLAG_MULTI, outb[0..pos]);
                    pos = 0;
                }
                emitted += 1;
            }
            if (pos > 0) { _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags | FLAG_MULTI, outb[0..pos]); }
            var done_empty: [0]u8 = {};
            _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags | FLAG_MULTI | FLAG_DONE, done_empty[0..]);
            return true;
        } else if (family == @intFromEnum(Family.registry) and op == @intFromEnum(Op.get)) {
            if (find_attr(attrs, @intFromEnum(AttrKind.key))) |k| {
                var pathbuf: [256]u8 = undefined;
                var plen: usize = 0;
                var i0: usize = 0; const pre = "/reg"; while (i0 < pre.len) : (i0 += 1) { pathbuf[plen] = pre[i0]; plen += 1; }
                pathbuf[plen] = '/'; plen += 1;
                var j0: usize = 0; while (j0 < k.len) : (j0 += 1) { pathbuf[plen] = k[j0]; plen += 1; }
                const pp = pathbuf[0..plen];
                if (vfs.UyaFS.read(pp)) |d| { _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags, d); return true; }
                var tlv: [16]u8 = undefined;
                const m = encode_err(tlv[0..], ERR_NOT_FOUND);
                _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags | FLAG_ACK, tlv[0..m]);
                return false;
            }
            var empty2: [0]u8 = {};
            _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags | FLAG_ACK, empty2[0..]);
            return false;
        } else if (family == @intFromEnum(Family.registry) and op == @intFromEnum(Op.set)) {
            const k = find_attr(attrs, @intFromEnum(AttrKind.key)) orelse null;
            const v = find_attr(attrs, @intFromEnum(AttrKind.value)) orelse null;
            if (k != null and v != null) {
                var pathbuf2: [256]u8 = undefined;
                var plen2: usize = 0;
                var i1: usize = 0; const pre2 = "/reg"; while (i1 < pre2.len) : (i1 += 1) { pathbuf2[plen2] = pre2[i1]; plen2 += 1; }
                pathbuf2[plen2] = '/'; plen2 += 1;
                var j1: usize = 0; while (j1 < k.?.len) : (j1 += 1) { pathbuf2[plen2] = k.?.[j1]; plen2 += 1; }
                const pp2 = pathbuf2[0..plen2];
                if (vfs.UyaFS.addFile(pp2, v.?)) {
                    var empty3: [0]u8 = {};
                    _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags | FLAG_ACK, empty3[0..]);
                    return true;
                } else {
                    var tlv2: [16]u8 = undefined;
                    const m2 = encode_err(tlv2[0..], ERR_DENIED);
                    _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags | FLAG_ACK, tlv2[0..m2]);
                    return false;
                }
            }
            var empty4: [0]u8 = {};
            _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags | FLAG_ACK, empty4[0..]);
            return false;
        } else if (family == @intFromEnum(Family.registry) and op == @intFromEnum(Op.list)) {
            var dirbuf2: [32]vfs.UyaFS.DirEntry = undefined;
            const n2 = vfs.UyaFS.list("/reg", dirbuf2[0..]);
            var outb2: [512]u8 = undefined;
            var p2: usize = 0;
            var i2: usize = 0;
            while (i2 < n2) : (i2 += 1) {
                var nm2: Attr = .{ .kind = @intFromEnum(AttrKind.name), .val = dirbuf2[i2].name };
                var isb: [1]u8 = [_]u8{ if (dirbuf2[i2].is_dir) 1 else 0 };
                var id2: Attr = .{ .kind = @intFromEnum(AttrKind.is_dir), .val = isb[0..] };
                var nx = append_attr(outb2[0..], p2, nm2);
                if (nx == p2) { _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags | FLAG_MULTI, outb2[0..p2]); p2 = 0; nx = append_attr(outb2[0..], p2, nm2); }
                p2 = append_attr(outb2[0..], nx, id2);
                if (p2 + 8 > outb2.len) { _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags | FLAG_MULTI, outb2[0..p2]); p2 = 0; }
            }
            if (p2 > 0) { _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags | FLAG_MULTI, outb2[0..p2]); }
            var done_empty2: [0]u8 = {};
            _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags | FLAG_MULTI | FLAG_DONE, done_empty2[0..]);
            return true;
        } else if (family == @intFromEnum(Family.process) and op == @intFromEnum(Op.list)) {
            var outb: [256]u8 = undefined;
            var pos: usize = 0;
            var ncores = percpu.count();
            var i3: usize = 0;
            while (i3 < ncores) : (i3 += 1) {
                const pc = percpu.get(i3).*;
                var cidb: [2]u8 = undefined; cidb[0] = @as(u8, @intCast(i3 & 0xFF)); cidb[1] = @as(u8, @intCast((i3 >> 8) & 0xFF));
                pos = append_attr(outb[0..], pos, .{ .kind = @intFromEnum(AttrKind.core_id), .val = cidb[0..] });
                var tb: [8]u8 = undefined; var ti: usize = 0; var tp: u64 = pc.tasks_processed; while (ti < 8) : (ti += 1) { tb[ti] = @as(u8, @intCast((tp >> (ti * 8)) & 0xFF)); }
                pos = append_attr(outb[0..], pos, .{ .kind = @intFromEnum(AttrKind.tasks), .val = tb[0..] });
                var kb: [8]u8 = undefined; var ki: usize = 0; var tk: u64 = pc.ticks; while (ki < 8) : (ki += 1) { kb[ki] = @as(u8, @intCast((tk >> (ki * 8)) & 0xFF)); }
                pos = append_attr(outb[0..], pos, .{ .kind = @intFromEnum(AttrKind.ticks), .val = kb[0..] });
                if (pos + 16 > outb.len) { _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags | FLAG_MULTI, outb[0..pos]); pos = 0; }
            }
            if (pos > 0) { _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags | FLAG_MULTI, outb[0..pos]); }
            var done_empty3: [0]u8 = {};
            _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags | FLAG_MULTI | FLAG_DONE, done_empty3[0..]);
            return true;
        } else if (family == @intFromEnum(Family.process) and op == @intFromEnum(Op.get)) {
            if (find_attr(attrs, @intFromEnum(AttrKind.core_id))) |cid| {
                var id: usize = @as(usize, cid[0]) | (@as(usize, cid[1]) << 8);
                if (id < percpu.count()) {
                    const pc2 = percpu.get(id).*;
                    var outb: [64]u8 = undefined;
                    var p: usize = 0;
                    var tb2: [8]u8 = undefined; var ti2: usize = 0; var tp2: u64 = pc2.tasks_processed; while (ti2 < 8) : (ti2 += 1) { tb2[ti2] = @as(u8, @intCast((tp2 >> (ti2 * 8)) & 0xFF)); }
                    p = append_attr(outb[0..], p, .{ .kind = @intFromEnum(AttrKind.tasks), .val = tb2[0..] });
                    var kb2: [8]u8 = undefined; var ki2: usize = 0; var tk2: u64 = pc2.ticks; while (ki2 < 8) : (ki2 += 1) { kb2[ki2] = @as(u8, @intCast((tk2 >> (ki2 * 8)) & 0xFF)); }
                    p = append_attr(outb[0..], p, .{ .kind = @intFromEnum(AttrKind.ticks), .val = kb2[0..] });
                    _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags, outb[0..p]);
                    return true;
                }
            }
            var tlv_err: [16]u8 = undefined; const me = encode_err(tlv_err[0..], ERR_NOT_FOUND);
            _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags | FLAG_ACK, tlv_err[0..me]);
            return false;
        } else if (family == @intFromEnum(Family.process) and op == @intFromEnum(Op.subscribe)) {
            const ok = proc_subscribe(ep);
            var empty_sub: [0]u8 = {};
            _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags | FLAG_ACK, empty_sub[0..]);
            return ok;
        }
        var empty3: [0]u8 = {};
        _ = events.endpoint_send_rsp_msg(ep, hdr.id, hdr.flags, empty3[0..]);
        return false;
    }
    return false;
}

fn encode_msg(mid: u64, flags: u32, data: []const u8, out: []u8) usize {
    var hdr: events.MsgHdr = .{ .id = mid, .flags = flags, .len = @as(u16, @intCast(data.len)), .err = 0, .deadline_ms = 0 };
    const hbytes: []const u8 = @as([*]const u8, @ptrCast(&hdr))[0..@sizeOf(events.MsgHdr)];
    if (hbytes.len + data.len > out.len) return 0;
    @memcpy(out[0..hbytes.len], hbytes);
    @memcpy(out[hbytes.len .. hbytes.len + data.len], data);
    return hbytes.len + data.len;
}

pub fn send_req_on_core(core: usize, ep: usize, family: u16, op: u16, attrs: []const Attr, flags: u32) bool {
    var tlv: [512]u8 = undefined;
    const n = encode_attrs(attrs, tlv[0..]);
    var buf: [512]u8 = undefined;
    const m = encode_msg(make_type(family, op), flags, tlv[0..n], buf[0..]);
    if (m == 0) return false;
    return events.core_send(core, @as(u16, @intCast(ep)), 0, buf[0..m]);
}

pub fn recv_core_msg(core: usize, out_hdr: *events.MsgHdr) ?[]const u8 {
    var ch: events.CoreMsgHdr = .{ .ep = 0, .dir = 0, .len = 0 };
    if (events.core_recv(core, &ch)) |b| {
        if (b.len < @sizeOf(events.MsgHdr)) return null;
        const hp: *const events.MsgHdr = @ptrCast(@alignCast(b.ptr));
        out_hdr.* = hp.*;
        const need: usize = @sizeOf(events.MsgHdr) + @as(usize, out_hdr.len);
        if (b.len < need) return null;
        return b[@sizeOf(events.MsgHdr) .. @sizeOf(events.MsgHdr) + @as(usize, out_hdr.len)];
    }
    return null;
}

pub fn handle_core_once(core: usize) bool {
    var ch: events.CoreMsgHdr = .{ .ep = 0, .dir = 0, .len = 0 };
    if (events.core_recv(core, &ch)) |b| {
        if (b.len < @sizeOf(events.MsgHdr)) return false;
        const hp: *const events.MsgHdr = @ptrCast(@alignCast(b.ptr));
        var hdr = hp.*;
        const family: u16 = @as(u16, @intCast(hdr.id >> 32));
        const op: u16 = @as(u16, @intCast(hdr.id & 0xFFFF));
        const payload = b[@sizeOf(events.MsgHdr) .. @sizeOf(events.MsgHdr) + @as(usize, hdr.len)];
        var attrs_buf: [8]Attr = undefined;
        const got = decode_attrs(payload, attrs_buf[0..]);
        const attrs = attrs_buf[0..got];
        if (family == @intFromEnum(Family.vfs) and op == @intFromEnum(Op.get)) {
            if (find_attr(attrs, @intFromEnum(AttrKind.path))) |p| {
                if (vfs.UyaFS.read(p)) |d| {
                    var outb: [512]u8 = undefined;
                    const m = encode_msg(hdr.id, hdr.flags, d, outb[0..]);
                    if (m == 0) return false;
                    _ = events.core_send(core, ch.ep, 1, outb[0..m]);
                    return true;
                }
            }
            var empty: [0]u8 = {};
            var outb2: [32]u8 = undefined;
            const m2 = encode_msg(hdr.id, hdr.flags, empty[0..], outb2[0..]);
            if (m2 != 0) _ = events.core_send(core, ch.ep, 1, outb2[0..m2]);
            return false;
        } else if (family == @intFromEnum(Family.vfs) and op == @intFromEnum(Op.list)) {
            var dirbuf: [32]vfs.UyaFS.DirEntry = undefined;
            const dirok = find_attr(attrs, @intFromEnum(AttrKind.dir)) orelse "/";
            const n = vfs.UyaFS.list(dirok, dirbuf[0..]);
            var tlv_block: [512]u8 = undefined;
            var pos: usize = 0;
            var off: usize = 0;
            var lim: usize = n;
            if (find_attr(attrs, @intFromEnum(AttrKind.offset))) |ao| { if (ao.len >= 2) { off = @as(usize, ao[0]) | (@as(usize, ao[1]) << 8); } }
            if (find_attr(attrs, @intFromEnum(AttrKind.limit))) |al| { if (al.len >= 2) { lim = @as(usize, al[0]) | (@as(usize, al[1]) << 8); } }
            var i: usize = 0;
            var emitted: usize = 0;
            while (i < n and emitted < lim) : (i += 1) {
                var nm_attr: Attr = .{ .kind = @intFromEnum(AttrKind.name), .val = dirbuf[i].name };
                var id_attr_buf: [1]u8 = undefined;
                id_attr_buf[0] = if (dirbuf[i].is_dir) 1 else 0;
                var id_attr: Attr = .{ .kind = @intFromEnum(AttrKind.is_dir), .val = id_attr_buf[0..] };
                if (i < off) continue;
                var next = append_attr(tlv_block[0..], pos, nm_attr);
                if (next == pos) {
                    var outb: [512]u8 = undefined;
                    const m = encode_msg(hdr.id, hdr.flags | FLAG_MULTI, tlv_block[0..pos], outb[0..]);
                    if (m != 0) _ = events.core_send(core, ch.ep, 1, outb[0..m]);
                    pos = 0;
                    next = append_attr(tlv_block[0..], pos, nm_attr);
                }
                pos = append_attr(tlv_block[0..], next, id_attr);
                if (pos + 8 > tlv_block.len) {
                    var outb2: [512]u8 = undefined;
                    const m2 = encode_msg(hdr.id, hdr.flags | FLAG_MULTI, tlv_block[0..pos], outb2[0..]);
                    if (m2 != 0) _ = events.core_send(core, ch.ep, 1, outb2[0..m2]);
                    pos = 0;
                }
                emitted += 1;
            }
            if (pos > 0) {
                var outb3: [512]u8 = undefined;
                const m3 = encode_msg(hdr.id, hdr.flags | FLAG_MULTI, tlv_block[0..pos], outb3[0..]);
                if (m3 != 0) _ = events.core_send(core, ch.ep, 1, outb3[0..m3]);
            }
            var done_empty: [0]u8 = {};
            var outb4: [64]u8 = undefined;
            const m4 = encode_msg(hdr.id, hdr.flags | FLAG_MULTI | FLAG_DONE, done_empty[0..], outb4[0..]);
            if (m4 != 0) _ = events.core_send(core, ch.ep, 1, outb4[0..m4]);
            return true;
        } else if (family == @intFromEnum(Family.registry) and op == @intFromEnum(Op.get)) {
            if (find_attr(attrs, @intFromEnum(AttrKind.key))) |k| {
                var pathbuf: [256]u8 = undefined;
                var plen: usize = 0;
                var i0: usize = 0; const pre = "/reg"; while (i0 < pre.len) : (i0 += 1) { pathbuf[plen] = pre[i0]; plen += 1; }
                pathbuf[plen] = '/'; plen += 1;
                var j0: usize = 0; while (j0 < k.len) : (j0 += 1) { pathbuf[plen] = k[j0]; plen += 1; }
                const pp = pathbuf[0..plen];
                if (vfs.UyaFS.read(pp)) |d| {
                    var outb: [512]u8 = undefined;
                    const m = encode_msg(hdr.id, hdr.flags, d, outb[0..]);
                    if (m != 0) _ = events.core_send(core, ch.ep, 1, outb[0..m]);
                    return true;
                }
                var tlv: [16]u8 = undefined;
                const en = encode_err(tlv[0..], ERR_NOT_FOUND);
                var outb2: [64]u8 = undefined;
                const m2 = encode_msg(hdr.id, hdr.flags | FLAG_ACK, tlv[0..en], outb2[0..]);
                if (m2 != 0) _ = events.core_send(core, ch.ep, 1, outb2[0..m2]);
                return false;
            }
            var empty3: [0]u8 = {};
            var outb3: [64]u8 = undefined;
            const m3 = encode_msg(hdr.id, hdr.flags | FLAG_ACK, empty3[0..], outb3[0..]);
            if (m3 != 0) _ = events.core_send(core, ch.ep, 1, outb3[0..m3]);
            return false;
        } else if (family == @intFromEnum(Family.registry) and op == @intFromEnum(Op.set)) {
            const k = find_attr(attrs, @intFromEnum(AttrKind.key)) orelse null;
            const v = find_attr(attrs, @intFromEnum(AttrKind.value)) orelse null;
            var outb4: [64]u8 = undefined;
            if (k != null and v != null) {
                var pathbuf2: [256]u8 = undefined;
                var plen2: usize = 0;
                var i1: usize = 0; const pre2 = "/reg"; while (i1 < pre2.len) : (i1 += 1) { pathbuf2[plen2] = pre2[i1]; plen2 += 1; }
                pathbuf2[plen2] = '/'; plen2 += 1;
                var j1: usize = 0; while (j1 < k.?.len) : (j1 += 1) { pathbuf2[plen2] = k.?.[j1]; plen2 += 1; }
                const pp2 = pathbuf2[0..plen2];
                var empty5: [0]u8 = {};
                if (vfs.UyaFS.addFile(pp2, v.?)) {
                    const m4 = encode_msg(hdr.id, hdr.flags | FLAG_ACK, empty5[0..], outb4[0..]);
                    if (m4 != 0) _ = events.core_send(core, ch.ep, 1, outb4[0..m4]);
                    return true;
                } else {
                    var tlv: [16]u8 = undefined;
                    const mtlv = encode_err(tlv[0..], ERR_DENIED);
                    const m5 = encode_msg(hdr.id, hdr.flags | FLAG_ACK, tlv[0..mtlv], outb4[0..]);
                    if (m5 != 0) _ = events.core_send(core, ch.ep, 1, outb4[0..m5]);
                    return false;
                }
            }
            var empty6: [0]u8 = {};
            const m6 = encode_msg(hdr.id, hdr.flags | FLAG_ACK, empty6[0..], outb4[0..]);
            if (m6 != 0) _ = events.core_send(core, ch.ep, 1, outb4[0..m6]);
            return false;
        } else if (family == @intFromEnum(Family.registry) and op == @intFromEnum(Op.list)) {
            var dirbuf2: [32]vfs.UyaFS.DirEntry = undefined;
            const n2 = vfs.UyaFS.list("/reg", dirbuf2[0..]);
            var tlv_block: [512]u8 = undefined;
            var pos: usize = 0;
            var i2: usize = 0;
            while (i2 < n2) : (i2 += 1) {
                var nm2: Attr = .{ .kind = @intFromEnum(AttrKind.name), .val = dirbuf2[i2].name };
                var isb: [1]u8 = [_]u8{ if (dirbuf2[i2].is_dir) 1 else 0 };
                var id2: Attr = .{ .kind = @intFromEnum(AttrKind.is_dir), .val = isb[0..] };
                var nx = append_attr(tlv_block[0..], pos, nm2);
                if (nx == pos) {
                    var outb: [512]u8 = undefined;
                    const m = encode_msg(hdr.id, hdr.flags | FLAG_MULTI, tlv_block[0..pos], outb[0..]);
                    if (m != 0) _ = events.core_send(core, ch.ep, 1, outb[0..m]);
                    pos = 0;
                    nx = append_attr(tlv_block[0..], pos, nm2);
                }
                pos = append_attr(tlv_block[0..], nx, id2);
                if (pos + 8 > tlv_block.len) {
                    var outb2: [512]u8 = undefined;
                    const m2 = encode_msg(hdr.id, hdr.flags | FLAG_MULTI, tlv_block[0..pos], outb2[0..]);
                    if (m2 != 0) _ = events.core_send(core, ch.ep, 1, outb2[0..m2]);
                    pos = 0;
                }
            }
            if (pos > 0) {
                var outb3: [512]u8 = undefined;
                const m3 = encode_msg(hdr.id, hdr.flags | FLAG_MULTI, tlv_block[0..pos], outb3[0..]);
                if (m3 != 0) _ = events.core_send(core, ch.ep, 1, outb3[0..m3]);
            }
            var done_empty2: [0]u8 = {};
            var outb4: [64]u8 = undefined;
            const m4 = encode_msg(hdr.id, hdr.flags | FLAG_MULTI | FLAG_DONE, done_empty2[0..], outb4[0..]);
            if (m4 != 0) _ = events.core_send(core, ch.ep, 1, outb4[0..m4]);
            return true;
        } else if (family == @intFromEnum(Family.process) and op == @intFromEnum(Op.list)) {
            var tlv_block: [256]u8 = undefined;
            var pos: usize = 0;
            var ncores = percpu.count();
            var i3: usize = 0;
            while (i3 < ncores) : (i3 += 1) {
                const pc = percpu.get(i3).*;
                var cidb: [2]u8 = undefined; cidb[0] = @as(u8, @intCast(i3 & 0xFF)); cidb[1] = @as(u8, @intCast((i3 >> 8) & 0xFF));
                pos = append_attr(tlv_block[0..], pos, .{ .kind = @intFromEnum(AttrKind.core_id), .val = cidb[0..] });
                var tb: [8]u8 = undefined; var ti: usize = 0; var tp: u64 = pc.tasks_processed; while (ti < 8) : (ti += 1) { tb[ti] = @as(u8, @intCast((tp >> (ti * 8)) & 0xFF)); }
                pos = append_attr(tlv_block[0..], pos, .{ .kind = @intFromEnum(AttrKind.tasks), .val = tb[0..] });
                var kb: [8]u8 = undefined; var ki: usize = 0; var tk: u64 = pc.ticks; while (ki < 8) : (ki += 1) { kb[ki] = @as(u8, @intCast((tk >> (ki * 8)) & 0xFF)); }
                pos = append_attr(tlv_block[0..], pos, .{ .kind = @intFromEnum(AttrKind.ticks), .val = kb[0..] });
                if (pos + 16 > tlv_block.len) {
                    var outb: [512]u8 = undefined;
                    const m = encode_msg(hdr.id, hdr.flags | FLAG_MULTI, tlv_block[0..pos], outb[0..]);
                    if (m != 0) _ = events.core_send(core, ch.ep, 1, outb[0..m]);
                    pos = 0;
                }
            }
            if (pos > 0) {
                var outb2: [512]u8 = undefined;
                const m2 = encode_msg(hdr.id, hdr.flags | FLAG_MULTI, tlv_block[0..pos], outb2[0..]);
                if (m2 != 0) _ = events.core_send(core, ch.ep, 1, outb2[0..m2]);
            }
            var done_empty3: [0]u8 = {};
            var outb3: [64]u8 = undefined;
            const m3 = encode_msg(hdr.id, hdr.flags | FLAG_MULTI | FLAG_DONE, done_empty3[0..], outb3[0..]);
            if (m3 != 0) _ = events.core_send(core, ch.ep, 1, outb3[0..m3]);
            return true;
        } else if (family == @intFromEnum(Family.process) and op == @intFromEnum(Op.get)) {
            if (find_attr(attrs, @intFromEnum(AttrKind.core_id))) |cid| {
                var id: usize = @as(usize, cid[0]) | (@as(usize, cid[1]) << 8);
                if (id < percpu.count()) {
                    const pc2 = percpu.get(id).*;
                    var tlv: [64]u8 = undefined;
                    var p: usize = 0;
                    var tb2: [8]u8 = undefined; var ti2: usize = 0; var tp2: u64 = pc2.tasks_processed; while (ti2 < 8) : (ti2 += 1) { tb2[ti2] = @as(u8, @intCast((tp2 >> (ti2 * 8)) & 0xFF)); }
                    p = append_attr(tlv[0..], p, .{ .kind = @intFromEnum(AttrKind.tasks), .val = tb2[0..] });
                    var kb2: [8]u8 = undefined; var ki2: usize = 0; var tk2: u64 = pc2.ticks; while (ki2 < 8) : (ki2 += 1) { kb2[ki2] = @as(u8, @intCast((tk2 >> (ki2 * 8)) & 0xFF)); }
                    p = append_attr(tlv[0..], p, .{ .kind = @intFromEnum(AttrKind.ticks), .val = kb2[0..] });
                    var outb4: [512]u8 = undefined;
                    const m4 = encode_msg(hdr.id, hdr.flags, tlv[0..p], outb4[0..]);
                    if (m4 != 0) _ = events.core_send(core, ch.ep, 1, outb4[0..m4]);
                    return true;
                }
            }
            var tlv_err: [16]u8 = undefined; const me = encode_err(tlv_err[0..], ERR_NOT_FOUND);
            var outb5: [64]u8 = undefined;
            const m5 = encode_msg(hdr.id, hdr.flags | FLAG_ACK, tlv_err[0..me], outb5[0..]);
            if (m5 != 0) _ = events.core_send(core, ch.ep, 1, outb5[0..m5]);
            return false;
        } else if (family == @intFromEnum(Family.process) and op == @intFromEnum(Op.subscribe)) {
            const ok = proc_subscribe(ch.ep);
            var empty_sub: [0]u8 = {};
            var outb6: [64]u8 = undefined;
            const m6 = encode_msg(hdr.id, hdr.flags | FLAG_ACK, empty_sub[0..], outb6[0..]);
            if (m6 != 0) _ = events.core_send(core, ch.ep, 1, outb6[0..m6]);
            return ok;
        } else if (family == @intFromEnum(Family.gc) and op == @intFromEnum(Op.set)) {
            var stepq: ?usize = null;
            var pauseq: ?usize = null;
            var aidx: usize = 0;
            while (aidx < attrs.len) : (aidx += 1) {
                if (attrs[aidx].kind == @intFromEnum(AttrKind.gc_step) and attrs[aidx].val.len >= 2) { stepq = @as(usize, attrs[aidx].val[0]) | (@as(usize, attrs[aidx].val[1]) << 8); }
                if (attrs[aidx].kind == @intFromEnum(AttrKind.gc_pause) and attrs[aidx].val.len >= 2) { pauseq = @as(usize, attrs[aidx].val[0]) | (@as(usize, attrs[aidx].val[1]) << 8); }
                if (attrs[aidx].kind == @intFromEnum(AttrKind.ai_model)) {
                    const m = attrs[aidx].val;
                    if (m.len >= 3 and m[0] == 'd') @import("gc_policy").set_model(@import("gc_policy").Model.doubao)
                    else if (m.len >= 4 and m[0] == 'q') @import("gc_policy").set_model(@import("gc_policy").Model.qwen)
                    else if (m.len >= 2 and m[0] == 'h') @import("gc_policy").set_model(@import("gc_policy").Model.hunyuan)
                    else if (m.len >= 2 and m[0] == 'e') @import("gc_policy").set_model(@import("gc_policy").Model.ensemble)
                    else @import("gc_policy").set_model(@import("gc_policy").Model.local);
                }
            }
            if (stepq) |sq| { @import("gc_policy").set_step_quota(sq); }
            if (pauseq) |pq| { @import("gc_policy").set_target_pause(pq); }
            @import("gc_api").start();
            var sb: [32]u8 = undefined;
            const n = @import("gc_api").stats(sb[0..]);
            var out: [64]u8 = undefined;
            const m = encode_msg(hdr.id, hdr.flags | FLAG_ACK, sb[0..n], out[0..]);
            if (m != 0) _ = events.core_send(core, ch.ep, 1, out[0..m]);
            return true;
        } else if (family == @intFromEnum(Family.gc) and op == @intFromEnum(Op.get)) {
            var sb: [32]u8 = undefined;
            const n = @import("gc_api").stats(sb[0..]);
            var out: [64]u8 = undefined;
            const m = encode_msg(hdr.id, hdr.flags | FLAG_ACK, sb[0..n], out[0..]);
            if (m != 0) _ = events.core_send(core, ch.ep, 1, out[0..m]);
            return true;
        } else if (family == @intFromEnum(Family.ai) and op == @intFromEnum(Op.get)) {
            var ptxt: []const u8 = "";
            var langtxt: []const u8 = "zig";
            var aidx2: usize = 0;
            while (aidx2 < attrs.len) : (aidx2 += 1) {
                if (attrs[aidx2].kind == @intFromEnum(AttrKind.prompt)) ptxt = attrs[aidx2].val;
                if (attrs[aidx2].kind == @intFromEnum(AttrKind.lang)) langtxt = attrs[aidx2].val;
            }
            var buf: [512]u8 = undefined;
            var s: []const u8 = @import("ai_doubao").gen(ptxt, langtxt);
            _ = @import("fs_vfs").UyaFS.addFile("/seed/code.zig", s);
            var attrc: Attr = .{ .kind = @intFromEnum(AttrKind.code), .val = s };
            const en = encode_attrs(&[_]Attr{ attrc }, buf[0..]);
            var outb: [512]u8 = undefined;
            const m = encode_msg(hdr.id, hdr.flags, buf[0..en], outb[0..]);
            if (m != 0) _ = events.core_send(core, ch.ep, 1, outb[0..m]);
            return true;
        } else if (family == @intFromEnum(Family.drv) and op == @intFromEnum(Op.set)) {
            var dev: []const u8 = "dev";
            var osrc: []const u8 = "linux";
            var ssrc: []const u8 = "pub fn driver() void {}";
            var a3: usize = 0;
            while (a3 < attrs.len) : (a3 += 1) {
                if (attrs[a3].kind == @intFromEnum(AttrKind.dev_id)) dev = attrs[a3].val;
                if (attrs[a3].kind == @intFromEnum(AttrKind.os_src)) osrc = attrs[a3].val;
                if (attrs[a3].kind == @intFromEnum(AttrKind.src)) ssrc = attrs[a3].val;
            }
            const outc = @import("driver_center").port(dev, osrc, ssrc);
            var bufp: [512]u8 = undefined;
            var attrp: Attr = .{ .kind = @intFromEnum(AttrKind.patched), .val = outc };
            const enp = encode_attrs(&[_]Attr{ attrp }, bufp[0..]);
            var outb6: [512]u8 = undefined;
            const m6 = encode_msg(hdr.id, hdr.flags | FLAG_ACK, bufp[0..enp], outb6[0..]);
            if (m6 != 0) _ = events.core_send(core, ch.ep, 1, outb6[0..m6]);
            return true;
        } else if (family == @intFromEnum(Family.drv) and op == @intFromEnum(Op.install)) {
            var dev: []const u8 = "dev";
            var ver: []const u8 = "current";
            var root: []const u8 = "/drivers";
            var i0: usize = 0;
            while (i0 < attrs.len) : (i0 += 1) {
                if (attrs[i0].kind == @intFromEnum(AttrKind.dev_id)) dev = attrs[i0].val;
                if (attrs[i0].kind == @intFromEnum(AttrKind.version)) ver = attrs[i0].val;
                if (attrs[i0].kind == @intFromEnum(AttrKind.root)) root = attrs[i0].val;
            }
            var allow: bool = true;
            if (@import("fs_vfs").UyaFS.read("/reg/security/drv_allow_install")) |v| {
                allow = !(v.len >= 5 and v[0] == 'f' and v[1] == 'a');
            }
            if (!allow) {
                var tlv: [64]u8 = undefined; var pos: usize = 0;
                var sb: [1]u8 = [_]u8{0}; pos = append_attr(tlv[0..], pos, .{ .kind = @intFromEnum(AttrKind.status), .val = sb[0..] });
                var eb: [1]u8 = [_]u8{ ERR_DENIED }; pos = append_attr(tlv[0..], pos, .{ .kind = @intFromEnum(AttrKind.errcode), .val = eb[0..] });
                const ltxt: []const u8 = "denied"; pos = append_attr(tlv[0..], pos, .{ .kind = @intFromEnum(AttrKind.log), .val = ltxt });
                var outb: [128]u8 = undefined; const m = encode_msg(hdr.id, hdr.flags | FLAG_ACK, tlv[0..pos], outb[0..]); if (m != 0) _ = events.core_send(core, ch.ep, 1, outb[0..m]);
                return false;
            }
            const ok = @import("driver_center").install(root, dev, ver);
            var tlv: [128]u8 = undefined;
            var pos: usize = 0;
            var sbuf: [1]u8 = [_]u8{ if (ok) 1 else 0 };
            pos = append_attr(tlv[0..], pos, .{ .kind = @intFromEnum(AttrKind.status), .val = sbuf[0..] });
            var eb: [1]u8 = [_]u8{ if (ok) 0 else ERR_NOT_FOUND };
            pos = append_attr(tlv[0..], pos, .{ .kind = @intFromEnum(AttrKind.errcode), .val = eb[0..] });
            const ltxt: []const u8 = if (ok) "ok" else "install failed";
            pos = append_attr(tlv[0..], pos, .{ .kind = @intFromEnum(AttrKind.log), .val = ltxt });
            var outb7: [256]u8 = undefined;
            const m7 = encode_msg(hdr.id, hdr.flags | FLAG_ACK, tlv[0..pos], outb7[0..]);
            if (m7 != 0) _ = events.core_send(core, ch.ep, 1, outb7[0..m7]);
            return ok;
        } else if (family == @intFromEnum(Family.drv) and op == @intFromEnum(Op.rollback)) {
            var dev: []const u8 = "dev";
            var ver: []const u8 = "current";
            var root: []const u8 = "/drivers";
            var i2: usize = 0;
            while (i2 < attrs.len) : (i2 += 1) {
                if (attrs[i2].kind == @intFromEnum(AttrKind.dev_id)) dev = attrs[i2].val;
                if (attrs[i2].kind == @intFromEnum(AttrKind.version)) ver = attrs[i2].val;
                if (attrs[i2].kind == @intFromEnum(AttrKind.root)) root = attrs[i2].val;
            }
            var allow_rb: bool = true;
            if (@import("fs_vfs").UyaFS.read("/reg/security/drv_allow_rollback")) |vr| {
                allow_rb = !(vr.len >= 5 and vr[0] == 'f' and vr[1] == 'a');
            }
            if (!allow_rb) {
                var tlv: [64]u8 = undefined; var pos: usize = 0;
                var sb: [1]u8 = [_]u8{0}; pos = append_attr(tlv[0..], pos, .{ .kind = @intFromEnum(AttrKind.status), .val = sb[0..] });
                var eb: [1]u8 = [_]u8{ ERR_DENIED }; pos = append_attr(tlv[0..], pos, .{ .kind = @intFromEnum(AttrKind.errcode), .val = eb[0..] });
                const ltxt: []const u8 = "denied"; pos = append_attr(tlv[0..], pos, .{ .kind = @intFromEnum(AttrKind.log), .val = ltxt });
                var outb: [128]u8 = undefined; const m = encode_msg(hdr.id, hdr.flags | FLAG_ACK, tlv[0..pos], outb[0..]); if (m != 0) _ = events.core_send(core, ch.ep, 1, outb[0..m]);
                return false;
            }
            const ok = @import("driver_center").rollback(root, dev, ver);
            var tlv2: [128]u8 = undefined; var pos2: usize = 0;
            var sb2: [1]u8 = [_]u8{ if (ok) 1 else 0 }; pos2 = append_attr(tlv2[0..], pos2, .{ .kind = @intFromEnum(AttrKind.status), .val = sb2[0..] });
            var eb2: [1]u8 = [_]u8{ if (ok) 0 else ERR_NOT_FOUND }; pos2 = append_attr(tlv2[0..], pos2, .{ .kind = @intFromEnum(AttrKind.errcode), .val = eb2[0..] });
            const lt2: []const u8 = if (ok) "ok" else "rollback failed"; pos2 = append_attr(tlv2[0..], pos2, .{ .kind = @intFromEnum(AttrKind.log), .val = lt2 });
            var outb8: [256]u8 = undefined; const m8 = encode_msg(hdr.id, hdr.flags | FLAG_ACK, tlv2[0..pos2], outb8[0..]); if (m8 != 0) _ = events.core_send(core, ch.ep, 1, outb8[0..m8]);
            return ok;
        } else if (family == @intFromEnum(Family.drv) and op == @intFromEnum(Op.verify)) {
            var dev: []const u8 = "dev";
            var i1: usize = 0;
            while (i1 < attrs.len) : (i1 += 1) {
                if (attrs[i1].kind == @intFromEnum(AttrKind.dev_id)) dev = attrs[i1].val;
            }
            const ok = @import("driver_center").verify(dev);
            var tlv: [128]u8 = undefined;
            var pos: usize = 0;
            var sbuf: [1]u8 = [_]u8{ if (ok) 1 else 0 };
            pos = append_attr(tlv[0..], pos, .{ .kind = @intFromEnum(AttrKind.status), .val = sbuf[0..] });
            var eb: [1]u8 = [_]u8{ if (ok) 0 else ERR_NOT_FOUND };
            pos = append_attr(tlv[0..], pos, .{ .kind = @intFromEnum(AttrKind.errcode), .val = eb[0..] });
            const ltxt: []const u8 = if (ok) "ok" else "verify failed";
            pos = append_attr(tlv[0..], pos, .{ .kind = @intFromEnum(AttrKind.log), .val = ltxt });
            var outb8: [256]u8 = undefined;
            const m8 = encode_msg(hdr.id, hdr.flags | FLAG_ACK, tlv[0..pos], outb8[0..]);
            if (m8 != 0) _ = events.core_send(core, ch.ep, 1, outb8[0..m8]);
            return ok;
        }
        }
        var outb5: [32]u8 = undefined;
        var empty5: [0]u8 = {};
        const m5 = encode_msg(hdr.id, hdr.flags, empty5[0..], outb5[0..]);
        if (m5 != 0) _ = events.core_send(core, ch.ep, 1, outb5[0..m5]);
        return false;
    }
    return false;
}

pub fn handle_core_drain(core: usize, limit: usize) usize {
    var handled: usize = 0;
    while (handled < limit) : (handled += 1) {
        if (!handle_core_once(core)) break;
    }
    return handled;
}

pub fn send_req_attrs_all(ep: usize, family: u16, op: u16, lists: [][]const Attr, flags: u32) usize {
    const MaxN: usize = 4;
    var bufs: [MaxN][512]u8 = undefined;
    var slices: [MaxN][]const u8 = undefined;
    var sent: usize = 0;
    var i: usize = 0;
    while (i < lists.len and sent < MaxN) : (i += 1) {
        const n = encode_attrs(lists[i], bufs[sent][0..]);
        slices[sent] = bufs[sent][0..n];
        sent += 1;
    }
    if (sent == 0) return 0;
    return events.endpoint_send_req_all(ep, slices[0..sent]);
}

pub fn send_req_on_core_batch(core: usize, ep: usize, family: u16, op: u16, lists: [][]const Attr, flags: u32) usize {
    const MaxN: usize = 4;
    var bufs: [MaxN][512]u8 = undefined;
    var out: usize = 0;
    var i: usize = 0;
    while (i < lists.len and out < MaxN) : (i += 1) {
        var tlv: [512]u8 = undefined;
        const n = encode_attrs(lists[i], tlv[0..]);
        const m = encode_msg(make_type(family, op), flags, tlv[0..n], bufs[out][0..]);
        if (m != 0) {
            _ = events.core_send(core, @as(u16, @intCast(ep)), 0, bufs[out][0..m]);
            out += 1;
        }
    }
    return out;
}
pub fn handle_drain(ep: usize, limit: usize) usize {
    var handled: usize = 0;
    while (handled < limit) : (handled += 1) {
        if (!handle_once(ep)) break;
    }
    return handled;
}
