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
    _ = n;
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
    serial.writeStr("SELFTEST\r\n");
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
