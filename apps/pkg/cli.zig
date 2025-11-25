const std = @import("std");
const builtin = @import("builtin");
const worktree = @import("worktree_mod");

fn usage() void {
    const o = std.io.getStdOut().writer();
    _ = o.print("apt init|import|install|list|remove|switch|add-source|update|install -r|lock|install-hex|apply-lock|diff-lock|check-lock\n", .{});
}

fn ensure_root(alloc: std.mem.Allocator, root: []const u8) !void {
    var p = std.fs.cwd();
    try p.makePath(root);
    const objs = try std.mem.concat(alloc, u8, &[_][]const u8{ root, "/objects/sha256" });
    defer alloc.free(objs);
    try p.makePath(objs);
    const wts = try std.mem.concat(alloc, u8, &[_][]const u8{ root, "/worktrees" });
    defer alloc.free(wts);
    try p.makePath(wts);
    const idx = try std.mem.concat(alloc, u8, &[_][]const u8{ root, "/index" });
    defer alloc.free(idx);
    try p.makePath(idx);
    const dls = try std.mem.concat(alloc, u8, &[_][]const u8{ root, "/downloads" });
    defer alloc.free(dls);
    try p.makePath(dls);
}

fn to_hex(alloc: std.mem.Allocator, bytes: []const u8) ![]u8 {
    const lut = "0123456789abcdef";
    const out = try alloc.alloc(u8, bytes.len * 2);
    var i: usize = 0;
    while (i < bytes.len) : (i += 1) {
        const b = bytes[i];
        out[i * 2] = lut[(b >> 4) & 0xF];
        out[i * 2 + 1] = lut[b & 0xF];
    }
    return out;
}

fn sha256_file(alloc: std.mem.Allocator, root: []const u8, path: []const u8) ![]u8 {
    var f = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer f.close();
    var h: std.crypto.hash.sha2.Sha256 = std.crypto.hash.sha2.Sha256.init(.{});
    var buf: [4096]u8 = undefined;
    while (true) {
        const n = try f.read(&buf);
        if (n == 0) break;
        h.update(buf[0..n]);
    }
    var sum: [32]u8 = undefined;
    h.final(&sum);
    const hexs = try to_hex(alloc, sum[0..]);
    const dst = try std.mem.concat(alloc, u8, &[_][]const u8{ root, "/objects/sha256/", hexs, ".blob" });
    defer alloc.free(dst);
    var srcf = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer srcf.close();
    var dstf = try std.fs.cwd().createFile(dst, .{});
    defer dstf.close();
    var buf2: [4096]u8 = undefined;
    while (true) {
        const n2 = try srcf.read(&buf2);
        if (n2 == 0) break;
        try dstf.writeAll(buf2[0..n2]);
    }
    return hexs;
}

pub fn main() !void {
    var gpa = std.heap.page_allocator;
    var it = try std.process.argsWithAllocator(gpa);
    defer it.deinit();
    _ = it.next();
    var cmd = it.next() orelse { usage(); return; };
    if (std.mem.eql(u8, cmd, "add")) cmd = "install";
    if (std.mem.eql(u8, cmd, "rm")) cmd = "remove";
    if (std.mem.eql(u8, cmd, "ls")) cmd = "list";
    const root = it.next() orelse "pkg";
    if (std.mem.eql(u8, cmd, "init")) {
        try ensure_root(gpa, root);
        return;
    } else if (std.mem.eql(u8, cmd, "import")) {
        const path = it.next() orelse { usage(); return; };
        try ensure_root(gpa, root);
        const hex = try sha256_file(gpa, root, path);
        const o = std.io.getStdOut().writer();
        _ = o.print("sha256 {s}\n", .{hex});
        return;
    } else if (std.mem.eql(u8, cmd, "install")) {
        const next = it.next() orelse { usage(); return; };
        if (std.mem.eql(u8, next, "-r")) {
            const name = it.next() orelse { usage(); return; };
            const version = it.next() orelse { usage(); return; };
            try ensure_root(gpa, root);
            var p = std.fs.cwd();
            const idxdir = try std.mem.concat(gpa, u8, &[_][]const u8{ root, "/index" });
            defer gpa.free(idxdir);
            var di = try p.openIterableDir(idxdir, .{});
            defer di.close();
            var itidx = di.iterate();
            var found: bool = false;
            var url_buf: []u8 = &[_]u8{};
            var hex_buf: []u8 = &[_]u8{};
            while (try itidx.next()) |e| {
                if (e.kind == .file) {
                    const fpath = try std.mem.concat(gpa, u8, &[_][]const u8{ idxdir, "/", e.name });
                    defer gpa.free(fpath);
                    var f = try p.openFile(fpath, .{ .mode = .read_only });
                    defer f.close();
                    var data = try f.readToEndAlloc(gpa, 1024 * 1024);
                    defer gpa.free(data);
                    var itl = std.mem.tokenizeAny(u8, data, "\r\n");
                    while (itl.next()) |line| {
                        if (line.len == 0) continue;
                        var toks = std.mem.tokenizeScalar(u8, line, ' ');
                        const pkg = toks.next() orelse continue;
                        const ver = toks.next() orelse continue;
                        const hex = toks.next() orelse continue;
                        const url = toks.next() orelse continue;
                        if (std.mem.eql(u8, pkg, name) and std.mem.eql(u8, ver, version)) {
                            hex_buf = try std.mem.allocPrint(gpa, "{s}", .{hex});
                            url_buf = try std.mem.allocPrint(gpa, "{s}", .{url});
                            found = true;
                            break;
                        }
                    }
                    if (found) break;
                }
            }
            if (!found) { usage(); return; }
            const dstdl = try std.mem.concat(gpa, u8, &[_][]const u8{ root, "/downloads/", name, "-", version, ".blob" });
            defer gpa.free(dstdl);
            if (std.mem.startsWith(u8, url_buf, "file://")) {
                const srcp = url_buf[7..];
                var sf = try p.openFile(srcp, .{ .mode = .read_only });
                defer sf.close();
                var df = try p.createFile(dstdl, .{});
                defer df.close();
                var buf: [4096]u8 = undefined;
                while (true) { const n = try sf.read(&buf); if (n == 0) break; try df.writeAll(buf[0..n]); }
            } else if (std.mem.startsWith(u8, url_buf, "http://")) {
                var client = std.http.Client.init(gpa);
                defer client.deinit();
                var req = try client.request(.GET, std.Uri.parse(url_buf) catch return, .{}, .{});
                try req.start(.{});
                try req.wait();
                var df2 = try p.createFile(dstdl, .{});
                defer df2.close();
                var buf2: [4096]u8 = undefined;
                while (true) { const rn = try req.reader().read(&buf2); if (rn == 0) break; try df2.writeAll(buf2[0..rn]); }
            } else { usage(); return; }
            try worktree.ensure(gpa, root, name, version);
            const rel = std.fs.path.basename(dstdl);
            try worktree.link_or_copy(gpa, root, "sha256", hex_buf, name, rel, version);
            try worktree.switch_current(gpa, root, name, version);
            const o2 = std.io.getStdOut().writer();
            _ = o2.print("installed {s}@{s} from remote\n", .{ name, version });
            return;
        } else {
            const name = next;
            const version = it.next() orelse { usage(); return; };
            const path = it.next() orelse { usage(); return; };
            try ensure_root(gpa, root);
            const hex = try sha256_file(gpa, root, path);
            try worktree.ensure(gpa, root, name, version);
            const rel = std.fs.path.basename(path);
            try worktree.link_or_copy(gpa, root, "sha256", hex, name, rel, version);
            try worktree.switch_current(gpa, root, name, version);
            const o = std.io.getStdOut().writer();
            _ = o.print("installed {s}@{s} -> {s}\n", .{ name, version, rel });
            return;
        }
    } else if (std.mem.eql(u8, cmd, "list")) {
        try ensure_root(gpa, root);
        var p = std.fs.cwd();
        const wdir = try std.mem.concat(gpa, u8, &[_][]const u8{ root, "/worktrees" });
        defer gpa.free(wdir);
        var d = try p.openIterableDir(wdir, .{});
        defer d.close();
        var itdir = d.iterate();
        const o = std.io.getStdOut().writer();
        while (try itdir.next()) |e| {
            if (e.kind == .directory) {
                const ndir = try std.mem.concat(gpa, u8, &[_][]const u8{ wdir, "/", e.name });
                defer gpa.free(ndir);
                var ed = try p.openIterableDir(ndir, .{});
                defer ed.close();
                var eit = ed.iterate();
                _ = o.print("{s}: ", .{e.name});
                while (try eit.next()) |ve| { if (ve.kind == .directory) _ = o.print("{s} ", .{ve.name}); }
                _ = o.print("\n", .{});
            }
        }
        return;
    } else if (std.mem.eql(u8, cmd, "remove")) {
        const name = it.next() orelse { usage(); return; };
        const version = it.next() orelse { usage(); return; };
        try ensure_root(gpa, root);
        var p = std.fs.cwd();
        const dirp = try std.mem.concat(gpa, u8, &[_][]const u8{ root, "/worktrees/", name, "/", version });
        defer gpa.free(dirp);
        try p.deleteTree(dirp);
        return;
    } else if (std.mem.eql(u8, cmd, "switch")) {
        const name = it.next() orelse { usage(); return; };
        const version = it.next() orelse { usage(); return; };
        try ensure_root(gpa, root);
        try worktree.switch_current(gpa, root, name, version);
        return;
    } else {
        if (std.mem.eql(u8, cmd, "add-source")) {
            const name = it.next() orelse { usage(); return; };
            const url = it.next() orelse { usage(); return; };
            try ensure_root(gpa, root);
            var p = std.fs.cwd();
            const sp = try std.mem.concat(gpa, u8, &[_][]const u8{ root, "/sources.txt" });
            defer gpa.free(sp);
            var old: []u8 = &[_]u8{};
            const exists = p.statFile(sp) catch null;
            if (exists != null) { var rf = try p.openFile(sp, .{ .mode = .read_only }); defer rf.close(); old = try rf.readToEndAlloc(gpa, 64 * 1024); }
            var wf = try p.createFile(sp, .{});
            defer wf.close();
            if (old.len > 0) { try wf.writeAll(old); gpa.free(old); }
            var line = try std.mem.concat(gpa, u8, &[_][]const u8{ name, " ", url, "\n" });
            defer gpa.free(line);
            try wf.writeAll(line);
            return;
        } else if (std.mem.eql(u8, cmd, "update")) {
            try ensure_root(gpa, root);
            var p = std.fs.cwd();
            const sp = try std.mem.concat(gpa, u8, &[_][]const u8{ root, "/sources.txt" });
            defer gpa.free(sp);
            var rf = try p.openFile(sp, .{ .mode = .read_only });
            defer rf.close();
            var data = try rf.readToEndAlloc(gpa, 64 * 1024);
            defer gpa.free(data);
            var itl = std.mem.tokenizeAny(u8, data, "\r\n");
            const idxdir = try std.mem.concat(gpa, u8, &[_][]const u8{ root, "/index" });
            defer gpa.free(idxdir);
            while (itl.next()) |line| {
                if (line.len == 0) continue;
                var toks = std.mem.tokenizeScalar(u8, line, ' ');
                const name = toks.next() orelse continue;
                const url = toks.next() orelse continue;
                var bytes: []u8 = &[_]u8{};
                if (std.mem.startsWith(u8, url, "file://")) {
                    const srcp = url[7..];
                    var sf = try p.openFile(srcp, .{ .mode = .read_only });
                    defer sf.close();
                    bytes = try sf.readToEndAlloc(gpa, 1024 * 1024);
                } else if (std.mem.startsWith(u8, url, "http://")) {
                    var client = std.http.Client.init(gpa);
                    defer client.deinit();
                    var req = try client.request(.GET, std.Uri.parse(url) catch continue, .{}, .{});
                    try req.start(.{});
                    try req.wait();
                    bytes = try req.reader().readAllAlloc(gpa, 8 * 1024 * 1024);
                } else continue;
                const idxpath = try std.mem.concat(gpa, u8, &[_][]const u8{ idxdir, "/", name, ".txt" });
                defer gpa.free(idxpath);
                var wf = try p.createFile(idxpath, .{});
                defer wf.close();
                try wf.writeAll(bytes);
                gpa.free(bytes);
            }
            return;
        } else if (std.mem.eql(u8, cmd, "lock")) {
            try ensure_root(gpa, root);
            var p = std.fs.cwd();
            const wdir = try std.mem.concat(gpa, u8, &[_][]const u8{ root, "/worktrees" });
            defer gpa.free(wdir);
            var d = try p.openIterableDir(wdir, .{});
            defer d.close();
            var itdir = d.iterate();
            const lf = try std.mem.concat(gpa, u8, &[_][]const u8{ root, "/apt.lock" });
            defer gpa.free(lf);
            var wf = try p.createFile(lf, .{});
            defer wf.close();
            const arch = @tagName(builtin.target.cpu.arch);
            const os = @tagName(builtin.target.os.tag);
            const hdr = try std.mem.concat(gpa, u8, &[_][]const u8{ "# abi=1 arch=", arch, " os=", os, "\n" });
            defer gpa.free(hdr);
            try wf.writeAll(hdr);
            while (try itdir.next()) |e| {
                if (e.kind != .directory) continue;
                const cur = try std.mem.concat(gpa, u8, &[_][]const u8{ wdir, "/", e.name, "/current" });
                defer gpa.free(cur);
                var cv = p.readFileAlloc(cur, gpa, 4096) catch continue;
                cv = std.mem.trim(u8, cv, " \t\r\n");
                const verdir = try std.mem.concat(gpa, u8, &[_][]const u8{ wdir, "/", e.name, "/", cv });
                defer gpa.free(verdir);
                var vd = p.openIterableDir(verdir, .{}) catch { gpa.free(cv); continue; };
                defer vd.close();
                var vit = vd.iterate();
                var found: bool = false;
                while (try vit.next()) |fe| {
                    if (fe.kind == .file) {
                        const fpath = try std.mem.concat(gpa, u8, &[_][]const u8{ verdir, "/", fe.name });
                        defer gpa.free(fpath);
                        var ff = try p.openFile(fpath, .{ .mode = .read_only });
                        defer ff.close();
                        var h: std.crypto.hash.sha2.Sha256 = std.crypto.hash.sha2.Sha256.init(.{});
                        var buf: [4096]u8 = undefined;
                        while (true) { const n = try ff.read(&buf); if (n == 0) break; h.update(buf[0..n]); }
                        var sum: [32]u8 = undefined; h.final(&sum);
                        const hexs = try to_hex(gpa, sum[0..]);
                        var line = try std.mem.concat(gpa, u8, &[_][]const u8{ e.name, " ", cv, " ", hexs, " ", fe.name, "\n" });
                        defer gpa.free(line);
                        try wf.writeAll(line);
                        gpa.free(hexs);
                        found = true; break;
                    }
                }
                gpa.free(cv);
            }
            return;
        } else if (std.mem.eql(u8, cmd, "install-hex")) {
            const name = it.next() orelse { usage(); return; };
            const version = it.next() orelse { usage(); return; };
            const hex = it.next() orelse { usage(); return; };
            const rel = it.next() orelse { usage(); return; };
            try ensure_root(gpa, root);
            try worktree.ensure(gpa, root, name, version);
            try worktree.link_or_copy(gpa, root, "sha256", hex, name, rel, version);
            try worktree.switch_current(gpa, root, name, version);
            return;
        } else if (std.mem.eql(u8, cmd, "apply-lock")) {
            const lockp = it.next() orelse { usage(); return; };
            try ensure_root(gpa, root);
            var data = std.fs.cwd().readFileAlloc(lockp, gpa, @enumFromInt(1 << 20)) catch { usage(); return; };
            defer gpa.free(data);
            var itl = std.mem.tokenizeAny(u8, data, "\r\n");
            while (itl.next()) |line| {
                if (line.len == 0) continue;
                var toks = std.mem.tokenizeScalar(u8, line, ' ');
                const name = toks.next() orelse continue;
                const ver = toks.next() orelse continue;
                const hex = toks.next() orelse continue;
                const rel = toks.next() orelse continue;
                try worktree.ensure(gpa, root, name, ver);
                try worktree.link_or_copy(gpa, root, "sha256", hex, name, rel, ver);
                try worktree.switch_current(gpa, root, name, ver);
            }
            return;
        } else if (std.mem.eql(u8, cmd, "diff-lock")) {
            const a = it.next() orelse { usage(); return; };
            const b = it.next() orelse { usage(); return; };
            var pa = std.fs.cwd().readFileAlloc(a, gpa, @enumFromInt(1 << 20)) catch { usage(); return; };
            defer gpa.free(pa);
            var pb = std.fs.cwd().readFileAlloc(b, gpa, @enumFromInt(1 << 20)) catch { usage(); return; };
            defer gpa.free(pb);
            const oa = std.mem.tokenizeAny(u8, pa, "\r\n");
            const ob = std.mem.tokenizeAny(u8, pb, "\r\n");
            var setA = std.AutoHashMap([]const u8, void).init(gpa);
            defer setA.deinit();
            var setB = std.AutoHashMap([]const u8, void).init(gpa);
            defer setB.deinit();
            var itA = oa;
            while (itA.next()) |la| { if (la.len == 0 or la[0] == '#') continue; _ = setA.put(la, {}); }
            var itB = ob;
            while (itB.next()) |lb| { if (lb.len == 0 or lb[0] == '#') continue; _ = setB.put(lb, {}); }
            const out = std.io.getStdOut().writer();
            var itAScan = setA.iterator();
            while (itAScan.next()) |e| { if (!setB.contains(e.key_ptr.*)) { _ = out.print("- {s}\n", .{ e.key_ptr.* }); } }
            var itBScan = setB.iterator();
            while (itBScan.next()) |e2| { if (!setA.contains(e2.key_ptr.*)) { _ = out.print("+ {s}\n", .{ e2.key_ptr.* }); } }
            return;
        } else if (std.mem.eql(u8, cmd, "check-lock")) {
            const lp = it.next() orelse { usage(); return; };
            var data = std.fs.cwd().readFileAlloc(lp, gpa, @enumFromInt(1 << 20)) catch { usage(); return; };
            defer gpa.free(data);
            var itl = std.mem.tokenizeAny(u8, data, "\r\n");
            const out = std.io.getStdOut().writer();
            var hdr: []const u8 = &[_]u8{};
            while (itl.next()) |line| { if (line.len == 0) continue; if (line[0] == '#') { hdr = line; break; } else break; }
            if (hdr.len == 0) { _ = out.print("no header\n", .{}); return; }
            const arch = @tagName(builtin.target.cpu.arch);
            const os = @tagName(builtin.target.os.tag);
            var ok: bool = true;
            if (!std.mem.containsAtLeast(u8, hdr, 1, arch)) { _ = out.print("arch mismatch: {s}\n", .{arch}); ok = false; }
            if (!std.mem.containsAtLeast(u8, hdr, 1, os)) { _ = out.print("os mismatch: {s}\n", .{os}); ok = false; }
            if (!std.mem.containsAtLeast(u8, hdr, 1, "abi=1")) { _ = out.print("abi mismatch\n", .{}); ok = false; }
            if (ok) { _ = out.print("lock OK\n", .{}); }
            return;
        } else {
            usage();
            return;
        }
    }
}
