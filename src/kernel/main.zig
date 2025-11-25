const serial = @import("arch/x86_64/serial.zig");
const st2 = @import("arch/x86_64/stivale2.zig");
const tables = @import("arch/x86_64/gdt_idt.zig");
const smp = @import("arch/x86_64/smp.zig");
const apic = @import("arch/x86_64/apic.zig");
const percpu = @import("arch/x86_64/percpu.zig");
const ap_boot = @import("arch/x86_64/ap_boot.zig");
const acpi = @import("arch/x86_64/acpi.zig");
const ap_start = @import("arch/x86_64/ap_start.zig");
const fb = @import("gfx/framebuffer.zig");
const mm = @import("mm_core");
const phys = @import("mm_phys");
const vfs = @import("fs_vfs");
const ring = @import("util_ring");
const seqlock_mod = @import("util_seqlock");
const iso_stub = @import("fs_iso_stub");
const events = @import("events");
const win_proc = @import("win_process");
const win_api = @import("win_api");
const win_thr = @import("win_thread");
const win_ctx = @import("win_context");
const win_sc = @import("win_syscall");
const persona = @import("abi_persona");
const cap_epoch = @import("cap_epoch");
const io_blk = @import("io_blk");
const drv_ramdisk = @import("drv_ramdisk");
const uyl = @import("uyalink");

pub export fn _start(st: *st2.Struct) noreturn {
    serial.init();
    st2.initHeaderChain();
    tables.init();
    vfs.UyaFS.init();
    _ = vfs.UyaFS.addFile("/etc/motd", "Welcome to UyaFS\r\n");
    _ = vfs.UyaFS.addFile("/etc/version", "UyaFS 0.1\r\n");
    iso_stub.mount_system();
    var dirbuf: [4]vfs.UyaFS.DirEntry = undefined;
    const n = vfs.UyaFS.list("/", dirbuf[0..]);
    serial.writeStr("VFS ");
    serial.writeHexU64(@as(u64, n));
    serial.writeStr("\r\n");
    st2.printBootStats(st);
    smp.init(st);
    apic.lapic_init();
    apic.ioapic_init();
    apic.timer_init();
    acpi.init();
    if (st2.getRsdpPtr(st)) |rp| {
        if (acpi.find_madt_from_rsdp(rp)) |m| {
            acpi.set_madt(m.addr, m.len);
            _ = acpi.parse_madt_lapic_ids();
            acpi.parse_madt_platform();
            acpi.register_to_apic();
            apic.build_initial_routes();
            apic.apply_routes();
        }
    }
    if (st2.getMemmap(st)) |m| {
        const entries: [*]phys.Entry = @as([*]phys.Entry, @ptrCast(m.ptr));
        phys.init(entries, m.len);
    }
    _ = mm.mm_map(undefined, 0x200000, 0x200000, 4096, .r);
    _ = mm.mm_protect(undefined, 0x200000, 4096, .x);
    _ = mm.mm_unmap(undefined, 0x200000, 4096);
    _ = vfs.UyaFS.read("/etc/motd");
    if (vfs.UyaFS.read("/etc/motd")) |msg| {
        serial.writeStr(msg);
    }
    fb.FB.init(st);
    const off_opt = fb.FB.allocBytes(1024, 64);
    if (off_opt) |off| {
        const p: [*]u8 = @ptrFromInt(fb.FB.addr + off);
        var i: usize = 0;
        while (i < 1024) : (i += 1) p[i] = @as(u8, @intCast(i & 0xFF));
        fb.FB.freeBytes(off, 1024);
    }
    events.init();
    events.channel_init();
    events.per_core_init(@as(usize, smp.get_count()));
    events.mpmc_init(@as(usize, smp.get_count()));
    events.mpmc_global_init();
    cap_epoch.set_core_count(@as(usize, smp.get_count()));
    io_blk.init();
    const rd = drv_ramdisk.init();
    _ = rd;
    const sched = @import("sched.zig");
    sched.init(@as(usize, smp.get_count()));
    const net = @import("net/stack.zig");
    net.init();
    const service = @import("service.zig");
    service.init(@as(usize, smp.get_count()));
    percpu.init(@as(usize, smp.get_count()));
    events.per_core_broadcast("hello");
    sched.run_once(0);
    if (smp.get_count() > 1) sched.run_once(1);
    ap_boot.start(@as(u32, smp.get_count()));
    var ci: u32 = 0;
    while (ci < smp.get_count()) : (ci += 1) apic.timer_enable(ci);
    apic.timer_tick(0);
    const sched2 = @import("sched.zig");
    sched2.run_ready(0);
    if (smp.get_count() > 1) {
        apic.timer_tick(1);
        sched2.run_ready(1);
    }
    ap_start.launch(@as(usize, smp.get_count()));
    const ch = events.channel_create();
    if (ch) |cid| {
        _ = events.channel_send(cid, "hello");
        _ = events.channel_recv(cid);
        _ = events.channel_close(cid);
    }
    events.push(1, 0x1E);
    if (events.pop()) |ev| {
        serial.writeStr("EV ");
        serial.writeHexU64(@as(u64, ev.code));
        serial.writeStr("\r\n");
    }
    _ = win_proc.create("/system/bin/hello.exe");
    var tk0: sched.Task = .{ .id = 1, .len = 5, .data = undefined };
    tk0.data[0] = 'c'; tk0.data[1] = 'o'; tk0.data[2] = 'r'; tk0.data[3] = 'e'; tk0.data[4] = '0';
    _ = sched.enqueue(0, tk0);
    if (smp.get_count() > 1) {
        var tk1: sched.Task = .{ .id = 2, .len = 5, .data = undefined };
        tk1.data[0] = 'c'; tk1.data[1] = 'o'; tk1.data[2] = 'r'; tk1.data[3] = 'e'; tk1.data[4] = 'X';
        _ = sched.enqueue(1, tk1);
    }
    _ = service.dispatch(.fs, "fs:mount");
    _ = service.dispatch(.process, "proc:create");
    _ = events.mpmc_push(0, "mp0");
    _ = events.mpmc_push(if (smp.get_count() > 1) 1 else 0, "mp1");
    _ = events.mpmc_pop();
    _ = events.mpmc_global_push("g1");
    _ = events.mpmc_global_push("g2");
    _ = events.mpmc_global_pop();
    const uproc = @import("user/process.zig");
    if (uproc.create_from_elf("/system/bin/hello.elf", 100)) |prc| {
        var pr = prc;
        uproc.run(&pr);
    }
    const usys = @import("user/syscall.zig");
    _ = usys.write("/var/log/demo", "demo");
    const sys = @import("syscall.zig");
    _ = sys.dispatch(1, 0, 0);
    const log = @import("log.zig");
    log.info("boot");
    const selftest = @import("tests/selftest.zig");
    selftest.run();
    const bench = @import("tests/bench.zig");
    bench.run();
    const zigabi = @import("zigabi");
    const zigmod = @import("plugin_zigmod");
    fn p_init() void {}
    fn p_fini() void {}
    fn p_call(id: u64, data: []const u8) usize { _ = id; _ = data.len; return 1; }
    var bt: zigabi.Table = .{ .version = 1, .init = &p_init, .fini = &p_fini, .call = &p_call };
    _ = zigmod.register("demo", &bt);
    _ = zigmod.register("gc_policy", @import("plugin_gc_policy_ai").get_table());
    _ = zigmod.register("doubao", @import("plugin_doubao").get_table());
    _ = zigmod.register("gc_policy_qwen", @import("plugin_gc_policy_qwen").get_table());
    _ = zigmod.register("gc_policy_hunyuan", @import("plugin_gc_policy_hunyuan").get_table());
    _ = zigmod.register("driver_doubao", @import("plugin_driver_doubao").get_table());
    _ = zigmod.register("driver_qwen", @import("plugin_driver_qwen").get_table());
    _ = zigmod.register("driver_hunyuan", @import("plugin_driver_hunyuan").get_table());
    _ = zigmod.register("doubao", @import("plugin_doubao").get_table());
    if (zigmod.get("demo")) |tp| {
        tp.init.*();
        const n = tp.call.*(1, "x", 1);
        _ = n;
        tp.fini.*();
    }
    serial.writeStr("SELFTEST\r\n");
    const sock = @import("net/socket.zig");
    if (sock.listen("svc")) |_| {
        if (sock.accept("svc")) |sv_| {
            if (sock.connect("svc")) |cl_| {
                var sv = sv_;
                var cl = cl_;
                _ = sock.set_quota("svc", 2, 2, 8);
                sock.bind_core(&sv, 0);
                sock.bind_core(&cl, 0);
                _ = sock.send(&cl, "C");
                _ = sock.send(&sv, "S");
                _ = sock.recv(&sv);
                _ = sock.recv(&cl);
                var arr: [3][]const u8 = .{ "A", "B", "C" };
                _ = sock.send_all(&cl, arr[0..]);
                var out: [3][]const u8 = undefined;
                const nb = sock.recv_batch(&sv, out[0..]);
                _ = nb;
                var hdr: @import("events").MsgHdr = .{ .id = 42, .flags = 7, .len = 0, .err = 0, .deadline_ms = 0 };
                _ = sock.send_msg(&cl, 42, 7, "X");
                _ = sock.recv_msg(&sv, &hdr);
                _ = sock.send_msg(&sv, 100, 1, "HI");
                _ = sock.recv(&cl);
                const ev = @import("events");
                ev.set_now(50);
                var mh: @import("events").MsgHdr = .{ .id = 200, .flags = 0, .len = 0, .err = 0, .deadline_ms = 60 };
                _ = sock.recv_until(&sv, &mh, 55);
                _ = sock.close(&sv);
                _ = sock.close(&cl);
            }
            _ = sock.unlisten("svc");
        }
    }
    if (events.endpoint_create()) |eid| {
        _ = events.endpoint_send_req(eid, "REQ");
        _ = events.endpoint_send_rsp(eid, "RSP");
        if (events.endpoint_recv_req(eid)) |rq| { _ = rq.len; }
        if (events.endpoint_recv_rsp(eid)) |rp| { _ = rp.len; }
        _ = events.endpoint_close(eid);
    }
    // blk quick self-check
    if (drv_ramdisk.id()) |rid| {
        var wbuf: [512]u8 = [_]u8{0} ** 512;
        wbuf[0] = 'U'; wbuf[1] = 'Y'; wbuf[2] = 'A';
        _ = io_blk.write(rid, 0, wbuf[0..]);
        var rbuf: [512]u8 = undefined;
        _ = io_blk.read(rid, 0, 1, rbuf[0..]);
        _ = rbuf[0] == 'U';
        var bpb: [512]u8 = [_]u8{0} ** 512;
        bpb[11] = 0x00; bpb[12] = 0x02;
        bpb[13] = 0x01;
        bpb[14] = 0x01; bpb[15] = 0x00;
        bpb[16] = 0x01;
        bpb[21] = 0xF8;
        bpb[32] = 16; bpb[33] = 0; bpb[34] = 0; bpb[35] = 0;
        bpb[36] = 1; bpb[37] = 0; bpb[38] = 0; bpb[39] = 0;
        bpb[44] = 2; bpb[45] = 0; bpb[46] = 0; bpb[47] = 0;
        bpb[510] = 0x55; bpb[511] = 0xAA;
        _ = io_blk.write(rid, 0, bpb[0..]);
        var fat: [512]u8 = [_]u8{0} ** 512;
        fat[0] = 0xF8; fat[1] = 0xFF; fat[2] = 0xFF; fat[3] = 0x0F;
        fat[4] = 0xFF; fat[5] = 0xFF; fat[6] = 0xFF; fat[7] = 0x0F;
        fat[8] = 0xFF; fat[9] = 0xFF; fat[10] = 0xFF; fat[11] = 0x0F;
        _ = io_blk.write(rid, 1, fat[0..]);
        var dir: [512]u8 = [_]u8{0} ** 512;
        dir[0] = 'H'; dir[1] = 'E'; dir[2] = 'L'; dir[3] = 'L'; dir[4] = 'O'; dir[5] = ' '; dir[6] = ' '; dir[7] = ' ';
        dir[8] = 'T'; dir[9] = 'X'; dir[10] = 'T';
        dir[11] = 0x20;
        dir[26] = 3; dir[27] = 0; dir[20] = 0; dir[21] = 0;
        dir[28] = 6; dir[29] = 0; dir[30] = 0; dir[31] = 0;
        _ = io_blk.write(rid, 2, dir[0..]);
        var fsec: [512]u8 = [_]u8{0} ** 512;
        fsec[0] = 'H'; fsec[1] = 'E'; fsec[2] = 'L'; fsec[3] = 'L'; fsec[4] = 'O'; fsec[5] = 0x0A;
        _ = io_blk.write(rid, 3, fsec[0..]);
        const fat32 = @import("fs_fat32");
        _ = fat32.mount(rid, "/mnt");
    }
    const fh = win_api.CreateFileA("/etc/motd");
    if (fh) |handle| {
        const sz = win_sc.dispatch(1, handle, 0);
        _ = sz;
        _ = win_sc.dispatch(2, handle, 0);
    }
    const p = win_proc.create("/system/bin/hello.exe");
    if (p) |pr| {
        const t = win_thr.create(pr.entry);
        var ctx = win_ctx.init(t.entry, t.sp);
        win_ctx.run(&ctx);
        const buf = [_]u8{ @as(u8, @intCast(pr.imports & 0xFF)) };
        _ = events.pushBytes(buf[0..]);
        _ = persona.dispatch(pr.kind, 1, 0, 0);
    }
    const sock2 = @import("net/socket.zig");
    if (sock2.pair()) |pp| {
        var client = pp.a;
        var server = pp.b;
        var ap_get: uyl.Attr = .{ .kind = @intFromEnum(uyl.AttrKind.path), .val = "/etc/motd" };
        const arr_get = [_]uyl.Attr{ ap_get };
        _ = uyl.send_req(client.ep, @intFromEnum(uyl.Family.vfs), @intFromEnum(uyl.Op.get), arr_get[0..], 0);
        _ = uyl.handle_drain(server.ep, 8);
        var rh1: @import("events").MsgHdr = .{ .id = 0, .flags = 0, .len = 0, .err = 0, .deadline_ms = 0 };
        _ = sock2.recv_msg(&client, &rh1);

        var ap_list: uyl.Attr = .{ .kind = @intFromEnum(uyl.AttrKind.dir), .val = "/" };
        const arr_list = [_]uyl.Attr{ ap_list };
        _ = uyl.send_req(client.ep, @intFromEnum(uyl.Family.vfs), @intFromEnum(uyl.Op.list), arr_list[0..], 0);
        _ = uyl.handle_drain(server.ep, 16);
        var rh2: @import("events").MsgHdr = .{ .id = 0, .flags = 0, .len = 0, .err = 0, .deadline_ms = 0 };
        var done: bool = false;
        while (!done) {
            if (sock2.recv_msg(&client, &rh2)) |payload| {
                if ((rh2.flags & uyl.FLAG_DONE) != 0) { done = true; } else { _ = payload.len; }
            } else {
                done = true;
            }
        }
        _ = sock2.close(&client);
        _ = sock2.close(&server);
    }

    const core_demo = @import("net/socket.zig");
    if (core_demo.pair()) |cp| {
        var cl = cp.a;
        var sv = cp.b;
        core_demo.bind_core(&cl, 0);
        core_demo.bind_core(&sv, 0);
        var apc: uyl.Attr = .{ .kind = @intFromEnum(uyl.AttrKind.path), .val = "/etc/version" };
        const arrc = [_]uyl.Attr{ apc };
        _ = uyl.send_req_on_core(0, cl.ep, @intFromEnum(uyl.Family.vfs), @intFromEnum(uyl.Op.get), arrc[0..], 0);
        _ = uyl.handle_core_drain(0, 8);
        var chdr: @import("events").MsgHdr = .{ .id = 0, .flags = 0, .len = 0, .err = 0, .deadline_ms = 0 };
        _ = uyl.recv_core_msg(0, &chdr);
        _ = core_demo.close(&cl);
        _ = core_demo.close(&sv);
    }

    const reg_demo = @import("net/socket.zig");
    if (reg_demo.pair()) |rp| {
        var cl = rp.a;
        var sv = rp.b;
        var ak: uyl.Attr = .{ .kind = @intFromEnum(uyl.AttrKind.key), .val = "theme" };
        var av: uyl.Attr = .{ .kind = @intFromEnum(uyl.AttrKind.value), .val = "dark" };
        const set_arr = [_]uyl.Attr{ ak, av };
        _ = uyl.send_req(cl.ep, @intFromEnum(uyl.Family.registry), @intFromEnum(uyl.Op.set), set_arr[0..], uyl.FLAG_ACK);
        _ = uyl.handle_drain(sv.ep, 8);
        var sh: @import("events").MsgHdr = .{ .id = 0, .flags = 0, .len = 0, .err = 0, .deadline_ms = 0 };
        _ = reg_demo.recv_msg(&cl, &sh);

        var ak2: uyl.Attr = .{ .kind = @intFromEnum(uyl.AttrKind.key), .val = "theme" };
        const get_arr = [_]uyl.Attr{ ak2 };
        _ = uyl.send_req(cl.ep, @intFromEnum(uyl.Family.registry), @intFromEnum(uyl.Op.get), get_arr[0..], 0);
        _ = uyl.handle_drain(sv.ep, 8);
        var gh: @import("events").MsgHdr = .{ .id = 0, .flags = 0, .len = 0, .err = 0, .deadline_ms = 0 };
        _ = reg_demo.recv_msg(&cl, &gh);

        _ = reg_demo.close(&cl);
        _ = reg_demo.close(&sv);
    }
    const ai_demo = @import("net/socket.zig");
    if (ai_demo.pair()) |ap| {
        var cl = ap.a;
        var sv = ap.b;
        var pr: @import("uyalink").Attr = .{ .kind = @intFromEnum(@import("uyalink").AttrKind.prompt), .val = "seed" };
        var lg: @import("uyalink").Attr = .{ .kind = @intFromEnum(@import("uyalink").AttrKind.lang), .val = "zig" };
        const arr = [_]@import("uyalink").Attr{ pr, lg };
        _ = @import("uyalink").send_req(cl.ep, @intFromEnum(@import("uyalink").Family.ai), @intFromEnum(@import("uyalink").Op.get), arr[0..], 0);
        _ = @import("uyalink").handle_drain(sv.ep, 8);
        var mh: @import("events").MsgHdr = .{ .id = 0, .flags = 0, .len = 0, .err = 0, .deadline_ms = 0 };
        if (ai_demo.recv_msg(&cl, &mh)) |payload| { _ = payload.len; }
        _ = ai_demo.close(&cl);
        _ = ai_demo.close(&sv);
    }
    const drv_demo = @import("net/socket.zig");
    if (drv_demo.pair()) |dp| {
        var cl = dp.a;
        var sv = dp.b;
        var osrc: @import("uyalink").Attr = .{ .kind = @intFromEnum(@import("uyalink").AttrKind.os_src), .val = "linux" };
        var devid: @import("uyalink").Attr = .{ .kind = @intFromEnum(@import("uyalink").AttrKind.dev_id), .val = "net0" };
        var srca: @import("uyalink").Attr = .{ .kind = @intFromEnum(@import("uyalink").AttrKind.src), .val = "pub fn driver() void {}" };
        const arrd = [_]@import("uyalink").Attr{ osrc, devid, srca };
        _ = @import("uyalink").send_req(cl.ep, @intFromEnum(@import("uyalink").Family.drv), @intFromEnum(@import("uyalink").Op.set), arrd[0..], 0);
        _ = @import("uyalink").handle_drain(sv.ep, 8);
        var mh2: @import("events").MsgHdr = .{ .id = 0, .flags = 0, .len = 0, .err = 0, .deadline_ms = 0 };
        if (drv_demo.recv_msg(&cl, &mh2)) |payload| { _ = payload.len; }
        _ = drv_demo.close(&cl);
        _ = drv_demo.close(&sv);
    }

    const proc_demo = @import("net/socket.zig");
    if (proc_demo.pair()) |ppp| {
        var clp = ppp.a;
        var svp = ppp.b;
        var sub_attr: uyl.Attr = .{ .kind = @intFromEnum(uyl.AttrKind.dir), .val = "/" };
        const sub_arr = [_]uyl.Attr{ sub_attr };
        _ = uyl.send_req(clp.ep, @intFromEnum(uyl.Family.process), @intFromEnum(uyl.Op.subscribe), sub_arr[0..], uyl.FLAG_ACK);
        _ = uyl.handle_drain(svp.ep, 4);
        var shp: @import("events").MsgHdr = .{ .id = 0, .flags = 0, .len = 0, .err = 0, .deadline_ms = 0 };
        _ = proc_demo.recv_msg(&clp, &shp);
        uyl.proc_notify_core(0);
        var nh: @import("events").MsgHdr = .{ .id = 0, .flags = 0, .len = 0, .err = 0, .deadline_ms = 0 };
        _ = proc_demo.recv_msg(&clp, &nh);
        _ = proc_demo.close(&clp);
        _ = proc_demo.close(&svp);
    }
    const lp = win_proc.create_linux();
    const lfd = persona.dispatch(lp.kind, 1, 1, 0);
    _ = persona.dispatch(lp.kind, 2, lfd, 1024);
    _ = persona.dispatch(lp.kind, 3, lfd, 0);
    const bp = win_proc.create_bsd();
    const bfd = persona.dispatch(bp.kind, 1, 2, 0);
    _ = persona.dispatch(bp.kind, 2, bfd, 1024);
    _ = persona.dispatch(bp.kind, 3, bfd, 0);
    const Stat = struct { a: u64 };
    var lock = seqlock_mod.SeqLock(Stat).init(.{ .a = 0 });
    lock.write(.{ .a = 1 });
    var snap: Stat = .{ .a = 0 };
    _ = lock.read(&snap);
    while (true) {}
}
    const comp = @import("gfx_comp");
    comp.init();
    if (comp.create_surface(200, 100)) |s0| {
        comp.fill_surface(s0, 0xFF2020FF);
        comp.blit(s0, 0, 0, 10, 10, 200, 100);
        comp.present();
        comp.destroy_surface(s0);
    }
    if (comp.create_surface(160, 120)) |a| {
        if (comp.create_surface(120, 80)) |b| {
            comp.fill_surface(a, 0xFF0000FF);
            comp.fill_surface(b, 0x00FF00FF);
            const la = comp.add_layer(a, 40, 40, 0) orelse 0;
            const lb = comp.add_layer(b, 60, 60, 1) orelse 1;
            comp.set_layer_opacity(lb, true);
            comp.mark_dirty(40, 40, 160, 120);
            comp.compose_dirty();
            comp.present_dirty();
            comp.set_layer_opacity(lb, false);
            comp.mark_dirty(60, 60, 120, 80);
            comp.compose_dirty();
            comp.present_dirty();
            comp.remove_layer(la);
            comp.remove_layer(lb);
            comp.destroy_surface(a);
            comp.destroy_surface(b);
        }
    }
    const gc = @import("gc_api");
    gc.init(1024 * 1024);
    if (gc.alloc(128)) |p1| {
        gc.register_root(p1, 128);
        if (gc.alloc(64)) |p2| {
            @import("gc_bar").write_barrier(p1, p2);
        }
        gc.start();
        var sbuf: [32]u8 = undefined;
        _ = gc.stats(sbuf[0..]);
    }
