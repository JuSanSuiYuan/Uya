const std = @import("std");

fn tryHardLinkUnix(src: []const u8, dst: []const u8, alloc: std.mem.Allocator) bool {
    _ = alloc;
    const c = @cImport({ @cInclude("unistd.h"); });
    const sZ = std.heap.page_allocator.alloc(u8, src.len + 1) catch return false;
    defer std.heap.page_allocator.free(sZ);
    const dZ = std.heap.page_allocator.alloc(u8, dst.len + 1) catch return false;
    defer std.heap.page_allocator.free(dZ);
    var i: usize = 0; while (i < src.len) : (i += 1) sZ[i] = src[i]; sZ[src.len] = 0;
    var j: usize = 0; while (j < dst.len) : (j += 1) dZ[j] = dst[j]; dZ[dst.len] = 0;
    return c.link(@ptrCast([*:0]const u8, sZ.ptr), @ptrCast([*:0]const u8, dZ.ptr)) == 0;
}

pub fn ensure(alloc: std.mem.Allocator, root: []const u8, prefix: []const u8, version: []const u8) !void {
    var p = std.fs.cwd();
    const dirp = try std.mem.concat(alloc, u8, &[_][]const u8{ root, "/worktrees/", prefix, "/", version });
    defer alloc.free(dirp);
    try p.makePath(dirp);
}

pub fn link_or_copy(alloc: std.mem.Allocator, root: []const u8, algo: []const u8, hash_hex: []const u8, prefix: []const u8, rel: []const u8, version: []const u8) !void {
    var p = std.fs.cwd();
    const objpath = try std.mem.concat(alloc, u8, &[_][]const u8{ root, "/objects/", algo, "/", hash_hex, ".blob" });
    defer alloc.free(objpath);
    const wdir = try std.mem.concat(alloc, u8, &[_][]const u8{ root, "/worktrees/", prefix, "/", version });
    defer alloc.free(wdir);
    try p.makePath(wdir);
    const dst = try std.mem.concat(alloc, u8, &[_][]const u8{ wdir, "/", rel });
    defer alloc.free(dst);
    const parent = std.fs.path.dirname(dst) orelse wdir;
    try p.makePath(parent);
    if (!tryHardLinkUnix(objpath, dst, alloc)) {
        var srcf = try std.fs.cwd().openFile(objpath, .{ .mode = .read_only });
        defer srcf.close();
        var dstf = try std.fs.cwd().createFile(dst, .{});
        defer dstf.close();
        var buf: [4096]u8 = undefined;
        while (true) {
            const n = try srcf.read(&buf);
            if (n == 0) break;
            try dstf.writeAll(buf[0..n]);
        }
    }
}

pub fn switch_current(alloc: std.mem.Allocator, root: []const u8, prefix: []const u8, version: []const u8) !void {
    var p = std.fs.cwd();
    const curfile = try std.mem.concat(alloc, u8, &[_][]const u8{ root, "/worktrees/", prefix, "/current" });
    defer alloc.free(curfile);
    var f = try p.createFile(curfile, .{});
    defer f.close();
    try f.writeAll(version);
}