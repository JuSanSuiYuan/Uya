const std = @import("std");
const builtin = @import("builtin");

extern "kernel32" fn CreateHardLinkW(lpFileName: [*:0]const u16, lpExistingFileName: [*:0]const u16, lpSecurityAttributes: ?*anyopaque) i32;

fn tryHardLink(src: []const u8, dst: []const u8, alloc: std.mem.Allocator) bool {
    if (builtin.os.tag != .windows) return false;
    const s16 = std.unicode.utf8ToUtf16LeAlloc(alloc, src) catch return false;
    defer alloc.free(s16);
    const d16 = std.unicode.utf8ToUtf16LeAlloc(alloc, dst) catch return false;
    defer alloc.free(d16);
    const sZ = alloc.alloc(u16, s16.len + 1) catch return false;
    defer alloc.free(sZ);
    const dZ = alloc.alloc(u16, d16.len + 1) catch return false;
    defer alloc.free(dZ);
    var i: usize = 0; while (i < s16.len) : (i += 1) sZ[i] = s16[i]; sZ[s16.len] = 0;
    var j: usize = 0; while (j < d16.len) : (j += 1) dZ[j] = d16[j]; dZ[d16.len] = 0;
    const sPtr: [*:0]const u16 = @ptrCast(sZ.ptr);
    const dPtr: [*:0]const u16 = @ptrCast(dZ.ptr);
    return CreateHardLinkW(sPtr, dPtr, null) != 0;
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
    if (!tryHardLink(objpath, dst, alloc)) {
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