const events = @import("events");
const cap_epoch = @import("cap_epoch");

pub fn run() void {
    events.mpmc_global_init();
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        var buf: [32]u8 = undefined;
        const n = i % buf.len;
        var k: usize = 0;
        while (k < n) : (k += 1) buf[k] = @as(u8, @intCast(k));
        _ = events.mpmc_global_push(buf[0..n]);
        if ((i % 7) == 0) cap_epoch.advance_all_cores();
        if ((i % 3) == 0) {
            _ = events.mpmc_global_pop();
        }
    }
    var drain: usize = 0;
    while (drain < 100) : (drain += 1) {
        _ = events.mpmc_global_pop();
        cap_epoch.advance_all_cores();
    }
    if (events.endpoint_create()) |eid| {
        _ = events.endpoint_send_req(eid, "rq");
        _ = events.endpoint_send_rsp(eid, "rp");
        _ = events.endpoint_recv_req(eid);
        _ = events.endpoint_recv_rsp(eid);
        var outs: [4][]const u8 = undefined;
        const got1 = events.endpoint_recv_req_batch(eid, outs[0..]);
        _ = got1;
        const got2 = events.endpoint_recv_rsp_batch(eid, outs[0..]);
        _ = got2;
        var hdr: @import("events").MsgHdr = .{ .id = 1, .flags = 0, .len = 0, .err = 0, .deadline_ms = 0 };
        _ = events.endpoint_send_req_msg(eid, 1, 0, "m");
        _ = events.endpoint_send_rsp_msg(eid, 2, 0, "n");
        _ = events.endpoint_recv_req_msg(eid, &hdr);
        _ = events.endpoint_recv_rsp_msg(eid, &hdr);
        _ = events.endpoint_send_req_msg(eid, 3, 1, "H");
        _ = events.endpoint_recv_req(eid);
        events.set_now(100);
        _ = events.endpoint_send_req_msg(eid, 4, 0, "T");
        _ = events.endpoint_close(eid);
    }
    const sock = @import("../net/socket.zig");
    if (sock.pair()) |p| {
        var a = p.a;
        var b = p.b;
        _ = sock.send_with_retry_deadline(&a, 9, 0, "Z", 10, 1);
        var mh: @import("events").MsgHdr = .{ .id = 0, .flags = 0, .len = 0, .err = 0, .deadline_ms = 5 };
        _ = sock.recv_until(&b, &mh, 3);
        events.set_ep_quota(a.ep, 1, 0, 2);
        sock.bind_core(&a, 0);
        sock.bind_core(&b, 0);
        _ = sock.send(&a, "core");
        _ = sock.recv(&b);
        _ = sock.close(&a);
        _ = sock.close(&b);
    }
    const uyl = @import("../net/uyalink.zig");
    const sock2 = @import("../net/socket.zig");
    if (sock2.pair()) |pp| {
        var client = pp.a;
        var server = pp.b;
        var ap: uyl.Attr = .{ .kind = @intFromEnum(uyl.AttrKind.dir), .val = "/" };
        const arr = [_]uyl.Attr{ ap };
        _ = uyl.send_req(client.ep, @intFromEnum(uyl.Family.vfs), @intFromEnum(uyl.Op.list), arr[0..], 0);
        _ = uyl.handle_drain(server.ep, 16);
        var hdr: @import("events").MsgHdr = .{ .id = 0, .flags = 0, .len = 0, .err = 0, .deadline_ms = 0 };
        var done: bool = false;
        while (!done) {
            if (sock2.recv_msg(&client, &hdr)) |payload| {
                if ((hdr.flags & uyl.FLAG_DONE) != 0) { done = true; } else { _ = payload.len; }
            } else { done = true; }
        }
        _ = sock2.close(&client);
        _ = sock2.close(&server);
    }
    const sock3 = @import("../net/socket.zig");
    if (sock3.pair()) |cp| {
        var cl = cp.a;
        var sv = cp.b;
        sock3.bind_core(&cl, 0);
        sock3.bind_core(&sv, 0);
        var apc: uyl.Attr = .{ .kind = @intFromEnum(uyl.AttrKind.path), .val = "/etc/motd" };
        const arrc = [_]uyl.Attr{ apc };
        _ = uyl.send_req_on_core(0, cl.ep, @intFromEnum(uyl.Family.vfs), @intFromEnum(uyl.Op.get), arrc[0..], 0);
        _ = uyl.handle_core_drain(0, 8);
        var chdr: @import("events").MsgHdr = .{ .id = 0, .flags = 0, .len = 0, .err = 0, .deadline_ms = 0 };
        _ = uyl.recv_core_msg(0, &chdr);
        _ = sock3.close(&cl);
        _ = sock3.close(&sv);
    }
    const sock4 = @import("../net/socket.zig");
    if (sock4.pair()) |rp| {
        var cl = rp.a;
        var sv = rp.b;
        var ak: uyl.Attr = .{ .kind = @intFromEnum(uyl.AttrKind.key), .val = "k1" };
        var av: uyl.Attr = .{ .kind = @intFromEnum(uyl.AttrKind.value), .val = "v1" };
        const set_arr = [_]uyl.Attr{ ak, av };
        _ = uyl.send_req(cl.ep, @intFromEnum(uyl.Family.registry), @intFromEnum(uyl.Op.set), set_arr[0..], uyl.FLAG_ACK);
        _ = uyl.handle_drain(sv.ep, 8);
        var sh: @import("events").MsgHdr = .{ .id = 0, .flags = 0, .len = 0, .err = 0, .deadline_ms = 0 };
        _ = sock4.recv_msg(&cl, &sh);
        var ak2: uyl.Attr = .{ .kind = @intFromEnum(uyl.AttrKind.key), .val = "k1" };
        const get_arr = [_]uyl.Attr{ ak2 };
        _ = uyl.send_req(cl.ep, @intFromEnum(uyl.Family.registry), @intFromEnum(uyl.Op.get), get_arr[0..], 0);
        _ = uyl.handle_drain(sv.ep, 8);
        var gh: @import("events").MsgHdr = .{ .id = 0, .flags = 0, .len = 0, .err = 0, .deadline_ms = 0 };
        _ = sock4.recv_msg(&cl, &gh);
        var i: usize = 0;
        while (i < 1000) : (i += 1) {
            var kbuf: [16]u8 = undefined;
            var klen: usize = 0;
            var j: usize = 0; const pre = "k"; while (j < pre.len) : (j += 1) { kbuf[klen] = pre[j]; klen += 1; }
            var d: usize = i % 10;
            kbuf[klen] = @as(u8, @intCast(48 + d)); klen += 1;
            var akk: uyl.Attr = .{ .kind = @intFromEnum(uyl.AttrKind.key), .val = kbuf[0..klen] };
            var avv: uyl.Attr = .{ .kind = @intFromEnum(uyl.AttrKind.value), .val = "x" };
            const sa = [_]uyl.Attr{ akk, avv };
            _ = uyl.send_req(cl.ep, @intFromEnum(uyl.Family.registry), @intFromEnum(uyl.Op.set), sa[0..], uyl.FLAG_ACK);
            _ = uyl.handle_drain(sv.ep, 16);
            var mh: @import("events").MsgHdr = .{ .id = 0, .flags = 0, .len = 0, .err = 0, .deadline_ms = 0 };
            _ = sock4.recv_msg(&cl, &mh);
        }
        _ = sock4.close(&cl);
        _ = sock4.close(&sv);
    }
    const sock5 = @import("../net/socket.zig");
    if (sock5.pair()) |pp| {
        var cl = pp.a;
        var sv = pp.b;
        var sa: uyl.Attr = .{ .kind = @intFromEnum(uyl.AttrKind.dir), .val = "/" };
        const arrs = [_]uyl.Attr{ sa };
        _ = uyl.send_req(cl.ep, @intFromEnum(uyl.Family.process), @intFromEnum(uyl.Op.subscribe), arrs[0..], uyl.FLAG_ACK);
        _ = uyl.handle_drain(sv.ep, 4);
        var mh0: @import("events").MsgHdr = .{ .id = 0, .flags = 0, .len = 0, .err = 0, .deadline_ms = 0 };
        _ = sock5.recv_msg(&cl, &mh0);
        uyl.proc_notify_core(0);
        var mh1: @import("events").MsgHdr = .{ .id = 0, .flags = 0, .len = 0, .err = 0, .deadline_ms = 0 };
        _ = sock5.recv_msg(&cl, &mh1);
        var cid: uyl.Attr = .{ .kind = @intFromEnum(uyl.AttrKind.core_id), .val = &[_]u8{0, 0} };
        const arrg = [_]uyl.Attr{ cid };
        _ = uyl.send_req(cl.ep, @intFromEnum(uyl.Family.process), @intFromEnum(uyl.Op.get), arrg[0..], 0);
        _ = uyl.handle_drain(sv.ep, 4);
        var mh2: @import("events").MsgHdr = .{ .id = 0, .flags = 0, .len = 0, .err = 0, .deadline_ms = 0 };
        _ = sock5.recv_msg(&cl, &mh2);
        _ = sock5.close(&cl);
        _ = sock5.close(&sv);
    }
    const owned = @import("../gc/owned.zig");
    const gcapi = @import("../gc/api.zig");
    const hazard = @import("../gc/hazard.zig");
    gcapi.init(256 * 1024);
    const OwnerA = struct{};
    const L1 = struct{};
    if (owned.Owned(u8[64], OwnerA).init()) |mut_o| {
        var o = mut_o;
        owned.with_epoch(L1, struct {
            fn run(_: L1) void {
                var b = o.borrow(L1);
                b.end();
            }
        }.run);
        o.drop();
    }
    if (gcapi.alloc_pinned(128)) |pp| {
        hazard.protect(pp);
        gcapi.start();
        hazard.clear();
    }
}
