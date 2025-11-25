const vfs = @import("fs_vfs");
const comp = @import("gfx_comp");
const fb = @import("gfx_fb");
const serial = @import("arch/x86_64/serial.zig");
const gcapi = @import("gc_api");
const gcmark = @import("gc_mark");
const gcsched = @import("gc_sched");
const dslist = @import("ds_list");
const percpu = @import("arch/x86_64/percpu.zig");
const drvcenter = @import("driver_center");

pub fn run() void {
    serial.writeStr("BENCH VFS 1K\r\n");
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        const p = if ((i % 2) == 0) "/etc/motd" else "/etc/version";
        _ = vfs.UyaFS.read(p);
    }
    serial.writeStr("DONE 1K\r\n");
    serial.writeStr("BENCH VFS 10K\r\n");
    var j: usize = 0;
    while (j < 10000) : (j += 1) {
        const p2 = if ((j % 2) == 0) "/etc/motd" else "/etc/version";
        _ = vfs.UyaFS.read(p2);
    }
    serial.writeStr("DONE 10K\r\n");
    gcapi.init(1024 * 1024);
    var objs: [1024][*]u8 = undefined;
    var i3: usize = 0;
    while (i3 < objs.len) : (i3 += 1) { objs[i3] = gcapi.alloc(64) orelse break; }
    if (objs[0] != null) {
        gcapi.register_root(objs[0], 64);
        gcmark.start_concurrent();
        gcmark.step();
        var sb: [32]u8 = undefined;
        _ = gcapi.stats(sb[0..]);
        serial.writeStr("GC MARK\r\n");
    }
    if (comp.create_surface(256, 128)) |s| {
        comp.fill_surface(s, 0xFF00A0FF);
        var lid_opt = comp.add_layer(s, 10, 10, 0);
        if (lid_opt) |_| {
            comp.mark_dirty(10, 10, 200, 64);
            comp.compose_dirty();
            comp.present_dirty();
        }
        comp.destroy_surface(s);
    }
    if (comp.create_surface(160, 120)) |a| {
        if (comp.create_surface(120, 80)) |b| {
            comp.fill_surface(a, 0xFF0000FF);
            comp.fill_surface(b, 0x00FF00FF);
            const la = comp.add_layer(a, 30, 30, 0) orelse 0;
            const lb = comp.add_layer(b, 50, 50, 1) orelse 1;
            comp.set_layer_opacity(lb, true);
            serial.writeStr("COMPOSE OPAQUE\r\n");
            comp.reset_metrics();
            comp.mark_dirty(30, 30, 160, 120);
            comp.compose_dirty();
            comp.present_dirty();
            const rows1 = comp.get_rows();
            const bytes1 = comp.get_bytes();
            serial.writeStr("ROWS ");
            serial.writeHexU64(rows1);
            serial.writeStr(" BYTES ");
            serial.writeHexU64(bytes1);
            serial.writeStr("\r\n");
            comp.set_layer_opacity(lb, false);
            serial.writeStr("COMPOSE TRANSPARENT\r\n");
            comp.reset_metrics();
            comp.mark_dirty(50, 50, 120, 80);
            comp.compose_dirty();
            comp.present_dirty();
            const rows2 = comp.get_rows();
            const bytes2 = comp.get_bytes();
            serial.writeStr("ROWS ");
            serial.writeHexU64(rows2);
            serial.writeStr(" BYTES ");
            serial.writeHexU64(bytes2);
            serial.writeStr("\r\n");
            comp.remove_layer(la);
            comp.remove_layer(lb);
            comp.destroy_surface(a);
            comp.destroy_surface(b);
        }
    }
    gcapi.init(2 * 1024 * 1024);
    var lst: dslist.List = .{ .head = @import("gc_tagptr").init() };
    dslist.init(&lst);
    var nodes: [1024]dslist.Node = undefined;
    var i4: usize = 0;
    while (i4 < 1024) : (i4 += 1) {
        const p = gcapi.alloc_pinned(32) orelse break;
        nodes[i4] = .{ .next = @import("gc_tagptr").init(), .val = i4, .payload = p };
        dslist.insert_head(&lst, &nodes[i4]);
        gcsched.per_core_step(1);
    }
    const owned = @import("gc_owned");
    const OwnerB = struct{};
    const Lx = struct{};
    if (owned.Owned(u8[16], OwnerB).init()) |mut_o2| {
        var o2 = mut_o2;
        var bm = o2.borrow_mut(Lx);
        owned.with_borrow_mut(u8[16], Lx, bm, struct { fn run(_: owned.BorrowMut(u8[16], Lx)) void {} }.run);
        o2.drop();
    }
    var removed = dslist.delete_even(&lst);
    const pause = gcsched.step_policy(0);
    var sb2: [16]u8 = undefined;
    const n2 = gcapi.stats(sb2[0..]);
    var mk: usize = 0;
    if (n2 >= 12) { mk = @as(usize, sb2[8]) | (@as(usize, sb2[9]) << 8) | (@as(usize, sb2[10]) << 16) | (@as(usize, sb2[11]) << 24); }
    @import("gc_policy").decide(pause, mk, @as(usize, sb2[12]) | (@as(usize, sb2[13]) << 8), @as(usize, sb2[14]) | (@as(usize, sb2[15]) << 8));
    const dirty = @import("gc_card").count_dirty();
    const retries = @import("ds_list").get_fail_count();
    const csz = @import("gc_policy").decide_card_size(dirty, pause);
    const nsz = @import("gc_policy").decide_nursery_size(pause, mk, @as(usize, sb2[12]) | (@as(usize, sb2[13]) << 8));
    const cth = @import("gc_policy").decide_compaction_threshold(@as(usize, sb2[14]) | (@as(usize, sb2[15]) << 8), pause);
    gcapi.set_nursery_size(nsz);
    serial.writeStr("DIRTY "); serial.writeHexU64(dirty); serial.writeStr(" RETRIES "); serial.writeHexU64(retries); serial.writeStr("\r\n");
    serial.writeStr("CARD_SIZE "); serial.writeHexU64(csz); serial.writeStr(" NURSERY "); serial.writeHexU64(nsz); serial.writeStr(" COMPACT "); serial.writeHexU64(cth); serial.writeStr("\r\n");
    serial.writeStr("GEN_AVG "); serial.writeHexU64(gcapi.get_gen_avg()); serial.writeStr(" NURSERY "); serial.writeHexU64(gcapi.get_nursery_size()); serial.writeStr("\r\n");
    serial.writeStr("LIST REMOVED "); serial.writeHexU64(removed); serial.writeStr("\r\n");
    serial.writeStr("GC MARKED "); serial.writeHexU64(mk); serial.writeStr("\r\n");
    serial.writeStr("PAUSE TICKS "); serial.writeHexU64(pause); serial.writeStr("\r\n");
    serial.writeStr("STEP QUOTA "); serial.writeHexU64(@import("gc_policy").get_step_quota()); serial.writeStr("\r\n");
    const mdl = @import("gc_policy").get_model();
    serial.writeStr("MODEL ");
    serial.writeStr(if (mdl == .doubao) "doubao\r\n" else if (mdl == .qwen) "qwen\r\n" else if (mdl == .hunyuan) "hunyuan\r\n" else if (mdl == .ensemble) "ensemble\r\n" else "local\r\n");
    serial.writeStr("DRV INSTALL\r\n");
    const ok_inst = drvcenter.install("/drivers", "net0", "v1");
    serial.writeStr(if (ok_inst) "OK\r\n" else "FAIL\r\n");
    serial.writeStr("DRV VERIFY\r\n");
    const ok_ver = drvcenter.verify("net0");
    serial.writeStr(if (ok_ver) "OK\r\n" else "FAIL\r\n");
    serial.writeStr("DRV ROLLBACK\r\n");
    const ok_rb = drvcenter.rollback("/drivers", "net0", "v0");
    serial.writeStr(if (ok_rb) "OK\r\n" else "FAIL\r\n");
    var ents: [32]vfs.UyaFS.DirEntry = undefined;
    const ac = vfs.UyaFS.list("/audit/driver/net0", ents[0..]);
    serial.writeStr("AUDIT COUNT "); serial.writeHexU64(ac); serial.writeStr("\r\n");
}
