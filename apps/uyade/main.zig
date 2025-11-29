const theme = @import("theme.zig");
const wm = @import("wm/manager.zig");
const start_btn = @import("components/start_button.zig");
const taskbar = @import("components/taskbar.zig");
const settings = @import("components/settings.zig");
const cfg = @import("components/config_loader.zig");
const std = @import("std");
const tray = @import("components/tray_init.zig");
const dsl = @import("dsl/parser.zig");
const browser_runner = @import("components/browser_runner.zig");
const titlebar_layout = @import("components/titlebar_layout.zig");
const titlebar_render = @import("components/titlebar_render.zig");
const Wyhash = std.hash.Wyhash;

fn readWorktreeFile(alloc: std.mem.Allocator, root: []const u8, prefix: []const u8, rel: []const u8) ?[]u8 {
    const curp = std.mem.concat(alloc, u8, &[_][]const u8{ root, "/worktrees/", prefix, "/current" }) catch return null;
    defer alloc.free(curp);
    const verbuf = std.fs.cwd().readFileAlloc(curp, alloc, @enumFromInt(4096)) catch return null;
    defer alloc.free(verbuf);
    const version = std.mem.trim(u8, verbuf, " \t\r\n");
    const full = std.mem.concat(alloc, u8, &[_][]const u8{ root, "/worktrees/", prefix, "/", version, "/", rel }) catch return null;
    return std.fs.cwd().readFileAlloc(full, alloc, @enumFromInt(1 << 16)) catch null;
}
fn applyBindString(alloc: std.mem.Allocator, bind: []const u8) ?[]u8 {
    if (!std.mem.startsWith(u8, bind, "registry://")) return null;
    const path = bind["registry://".len..];
    const last_slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return null;
    const prefix = path[0..last_slash];
    const rel = path[last_slash + 1 ..];
    return readWorktreeFile(alloc, "registry", prefix, rel);
}

pub fn main() void {
    theme.load();
    var prefs = settings.Settings.init();
    const alloc = std.heap.page_allocator;
    const loaded = cfg.load("registry", "org/uya/uyade", alloc);
    prefs = loaded;
    prefs.vert_seconds = false;
    prefs.horiz_seconds = true;
    prefs.accent = .pink;
    const ui_path = "registry/worktrees/org/uya/uyade/ui.dsl";
    if (std.fs.cwd().readFileAlloc(ui_path, alloc, @enumFromInt(1 << 16))) |buf| {
        if (dsl.parse(alloc, buf)) |doc| {
            if (dsl.findString(&doc, "theme", "accent")) |acc| {
                if (std.mem.eql(u8, acc, "pink")) prefs.accent = .pink
                else if (std.mem.eql(u8, acc, "sky")) prefs.accent = .sky
                else if (std.mem.eql(u8, acc, "mint")) prefs.accent = .mint;
            }
            if (dsl.findString(&doc, "taskbar", "orientation")) |ori| {
                if (std.mem.eql(u8, ori, "bottom")) {}
                else if (std.mem.eql(u8, ori, "top")) {
                    prefs.bar_orientation = .top;
                } else if (std.mem.eql(u8, ori, "left")) {
                    prefs.bar_orientation = .left;
                } else if (std.mem.eql(u8, ori, "right")) {
                    prefs.bar_orientation = .right;
                }
            }
            if (dsl.findBool(&doc, "clock", "show_seconds")) |ss| {
                prefs.horiz_seconds = ss;
                prefs.vert_seconds = ss;
            }
            // optional binds override from registry paths
            if (dsl.findString(&doc, "bind", "theme.accent")) |b1| {
                if (applyBindString(alloc, b1)) |val| {
                    const v = std.mem.trim(u8, val, " \t\r\n");
                    if (std.mem.eql(u8, v, "pink")) prefs.accent = .pink
                    else if (std.mem.eql(u8, v, "sky")) prefs.accent = .sky
                    else if (std.mem.eql(u8, v, "mint")) prefs.accent = .mint;
                    alloc.free(val);
                }
            }
            if (dsl.findString(&doc, "bind", "taskbar.orientation")) |b2| {
                if (applyBindString(alloc, b2)) |val2| {
                    const v2 = std.mem.trim(u8, val2, " \t\r\n");
                    if (std.mem.eql(u8, v2, "top")) prefs.bar_orientation = .top
                    else if (std.mem.eql(u8, v2, "left")) prefs.bar_orientation = .left
                    else if (std.mem.eql(u8, v2, "right")) prefs.bar_orientation = .right
                    else prefs.bar_orientation = .bottom;
                    alloc.free(val2);
                }
            }
            if (dsl.findString(&doc, "bind", "clock.show_seconds")) |b3| {
                if (applyBindString(alloc, b3)) |val3| {
                    const v3 = std.mem.trim(u8, val3, " \t\r\n");
                    const ssb = std.mem.eql(u8, v3, "true");
                    prefs.horiz_seconds = ssb;
                    prefs.vert_seconds = ssb;
                    alloc.free(val3);
                }
            }
        } else |_| {}
        alloc.free(buf);
    } else |_| {}
    prefs.apply();
    var mgr = wm.Manager.init();
    titlebar_render.render_with_size(screen_w, screen_h);
    titlebar_render.render_ascii(80, 1);
    const alloc2 = std.heap.page_allocator;
    const mp_gfx = std.fs.cwd().readFileAlloc("registry/metrics_gfx.txt", alloc2, @enumFromInt(1 << 16)) catch null;
    const mp_gc = std.fs.cwd().readFileAlloc("registry/metrics_gc.txt", alloc2, @enumFromInt(1 << 16)) catch null;
    const mp_drv = std.fs.cwd().readFileAlloc("registry/metrics_drv.txt", alloc2, @enumFromInt(1 << 16)) catch null;
    if (mp_gfx) |g| { _ = std.io.getStdOut().writer().print("METRICS GFX\n{s}\n", .{g}); alloc2.free(g); }
    if (mp_gc) |c| { _ = std.io.getStdOut().writer().print("METRICS GC\n{s}\n", .{c}); alloc2.free(c); }
    if (mp_drv) |d| { _ = std.io.getStdOut().writer().print("METRICS DRV\n{s}\n", .{d}); alloc2.free(d); }
    const kvlog = std.fs.cwd().readFileAlloc("db/registry/kv.log", alloc2, @enumFromInt(1 << 16)) catch null;
    const wtlog = std.fs.cwd().readFileAlloc("db/registry/worktree.log", alloc2, @enumFromInt(1 << 16)) catch null;
    const swlog = std.fs.cwd().readFileAlloc("db/registry/switch.log", alloc2, @enumFromInt(1 << 16)) catch null;
    if (kvlog) |kvl| { _ = std.io.getStdOut().writer().print("DB REG KV\n{s}\n", .{kvl}); alloc2.free(kvl); }
    if (wtlog) |wtl| { _ = std.io.getStdOut().writer().print("DB REG WT\n{s}\n", .{wtl}); alloc2.free(wtl); }
    if (swlog) |swl| { _ = std.io.getStdOut().writer().print("DB REG SWITCH\n{s}\n", .{swl}); alloc2.free(swl); }
    var count_audit: usize = 0;
    if (std.fs.cwd().openDir("db/driver_audit/net0", .{ .iterate = true })) |dir| {
        var it = dir.iterate();
        while (true) {
            const nxt = it.next() catch break;
            if (nxt == null) break;
            count_audit += 1;
        }
    } else |_| {}
    _ = std.io.getStdOut().writer().print("DB AUDIT COUNT {d}\n", .{count_audit});
    const screen_w: u32 = 1280;
    const screen_h: u32 = 800;
    var bar = taskbar.Taskbar.init(screen_w, screen_h, prefs.getBarOrientation());
    _ = mgr.createMaximizedWindow("UyaDE", screen_w, screen_h, bar);
    var want_taskbar = true;
    var want_start = true;
    var want_tray = true;
    var want_clock = true;
    var ty = tray.create();
    if (std.fs.cwd().readFileAlloc(ui_path, alloc, @enumFromInt(1 << 16))) |buf2| {
        if (dsl.parse(alloc, buf2)) |doc2| {
            if (dsl.findStringArray(&doc2, "layout", "children")) |chs| {
                want_taskbar = false;
                want_start = false;
                want_tray = false;
                want_clock = false;
                for (chs) |name| {
                    if (std.mem.eql(u8, name, "taskbar")) want_taskbar = true;
                    if (std.mem.eql(u8, name, "start")) want_start = true;
                    if (std.mem.eql(u8, name, "tray")) want_tray = true;
                    if (std.mem.eql(u8, name, "clock")) want_clock = true;
                }
            }
            if (dsl.findStringArray(&doc2, "tray", "icons")) |arr2| {
                _ = ty.replaceIcons(alloc, arr2) catch {};
            } else {
                var def_arr = [_][]const u8{ "default" };
                const def_slice: [][]const u8 = def_arr[0..];
                _ = ty.replaceIcons(alloc, def_slice) catch {};
            }
        } else |_| {}
        alloc.free(buf2);
    } else |_| {}
    if (!want_taskbar) {
        // If not wanted, optionally skip using bar in first window; kept for compatibility.
    }
    if (want_start) { const sb = start_btn.StartButton.init(screen_w, screen_h); _ = sb; }
    if (want_tray) {}
    const drop_x: i32 = 4;
    const drop_y: i32 = 4;
    const new_ori = taskbar.Taskbar.inferOrientationFromDrag(drop_x, drop_y, screen_w, screen_h);
    bar.reorient(screen_w, screen_h, new_ori);
    _ = mgr.createMaximizedWindow("UyaDE-2", screen_w, screen_h, bar);
    const sb2 = start_btn.StartButton.init(screen_w, screen_h);
    _ = sb2;
    var ui_hash: u64 = 0;
    // launch a simple browser fetch and save, then read content to verify
    browser_runner.open_url_and_save("https://example.com/", 80, alloc);
    const br_path = "registry/worktrees/org/uya/browser/demo/page.txt";
    if (std.fs.cwd().readFileAlloc(br_path, alloc, @enumFromInt(1 << 20))) |br| {
        // use hash to detect changes in saved browser content
        const br_hash = Wyhash.hash(0, br);
        _ = br_hash;
        alloc.free(br);
    } else |_| {}
    if (std.fs.cwd().readFileAlloc(ui_path, alloc, @enumFromInt(1 << 16))) |bufh| {
        ui_hash = Wyhash.hash(0, bufh);
        alloc.free(bufh);
    } else |_| {}
    var iter: usize = 0;
    while (iter < 1000000) : (iter += 1) {
        var spin: usize = 0;
        while (spin < 10_000_000) : (spin += 1) {}
        if (std.fs.cwd().readFileAlloc(ui_path, alloc, @enumFromInt(1 << 16))) |bufr| {
            const h = Wyhash.hash(0, bufr);
            if (h != ui_hash) {
                ui_hash = h;
                if (dsl.parse(alloc, bufr)) |docr| {
                    if (dsl.findString(&docr, "theme", "accent")) |acc2| {
                        if (std.mem.eql(u8, acc2, "pink")) prefs.accent = .pink
                        else if (std.mem.eql(u8, acc2, "sky")) prefs.accent = .sky
                        else if (std.mem.eql(u8, acc2, "mint")) prefs.accent = .mint;
                    }
                    if (dsl.findString(&docr, "taskbar", "orientation")) |ori2| {
                        if (std.mem.eql(u8, ori2, "top")) {
                            prefs.bar_orientation = .top;
                        } else if (std.mem.eql(u8, ori2, "left")) {
                            prefs.bar_orientation = .left;
                        } else if (std.mem.eql(u8, ori2, "right")) {
                            prefs.bar_orientation = .right;
                        } else {
                            prefs.bar_orientation = .bottom;
                        }
                    }
                    if (dsl.findBool(&docr, "clock", "show_seconds")) |ss2| {
                        prefs.horiz_seconds = ss2;
                        prefs.vert_seconds = ss2;
                    }
                    if (dsl.findString(&docr, "bind", "theme.accent")) |bb1| {
                        if (applyBindString(alloc, bb1)) |v1| {
                            const vv1 = std.mem.trim(u8, v1, " \t\r\n");
                            if (std.mem.eql(u8, vv1, "pink")) prefs.accent = .pink
                            else if (std.mem.eql(u8, vv1, "sky")) prefs.accent = .sky
                            else if (std.mem.eql(u8, vv1, "mint")) prefs.accent = .mint;
                            alloc.free(v1);
                        }
                    }
                    if (dsl.findString(&docr, "bind", "taskbar.orientation")) |bb2| {
                        if (applyBindString(alloc, bb2)) |v2| {
                            const vv2 = std.mem.trim(u8, v2, " \t\r\n");
                            if (std.mem.eql(u8, vv2, "top")) prefs.bar_orientation = .top
                            else if (std.mem.eql(u8, vv2, "left")) prefs.bar_orientation = .left
                            else if (std.mem.eql(u8, vv2, "right")) prefs.bar_orientation = .right
                            else prefs.bar_orientation = .bottom;
                            alloc.free(v2);
                        }
                    }
                    if (dsl.findString(&docr, "bind", "clock.show_seconds")) |bb3| {
                        if (applyBindString(alloc, bb3)) |v3| {
                            const vv3 = std.mem.trim(u8, v3, " \t\r\n");
                            const ssv = std.mem.eql(u8, vv3, "true");
                            prefs.horiz_seconds = ssv;
                            prefs.vert_seconds = ssv;
                            alloc.free(v3);
                        }
                    }
                    prefs.apply();
                    const cur_ori = bar.orientation;
                    var new_o: taskbar.Orientation = cur_ori;
                    new_o = prefs.getBarOrientation();
                    if (new_o != cur_ori) bar.reorient(screen_w, screen_h, new_o);
                    var def2_arr = [_][]const u8{ "default" };
                    const def2_slice: [][]const u8 = def2_arr[0..];
                    if (dsl.findStringArray(&docr, "tray", "icons")) |arrn| {
                        if (!ty.equalsOrder(arrn)) { _ = ty.replaceIcons(alloc, arrn) catch {}; }
                    } else {
                        if (!ty.equalsOrder(def2_slice)) { _ = ty.replaceIcons(alloc, def2_slice) catch {}; }
                    }
                } else |_| {}
            }
            alloc.free(bufr);
        } else |_| {}
    }
}
            if (dsl.findString(&doc, "titlebar", "layout")) |tb| {
                titlebar_layout.apply(tb);
            }
            if (dsl.findStringArray(&doc, "titlebar", "controls.left")) |larr| {
                titlebar_layout.set_left(alloc, larr);
            }
            if (dsl.findStringArray(&doc, "titlebar", "controls.right")) |rarr| {
                titlebar_layout.set_right(alloc, rarr);
            }
            if (dsl.findString(&doc, "titlebar", "size")) |sz| {
                const s = std.fmt.parseInt(usize, sz, 10) catch 24;
                if (dsl.findString(&doc, "titlebar", "spacing")) |sp| {
                    const spx = std.fmt.parseInt(usize, sp, 10) catch 8;
                    @import("components/titlebar_calc.zig").set_metrics(s, spx);
                } else {
                    @import("components/titlebar_calc.zig").set_metrics(s, 8);
                }
            }
