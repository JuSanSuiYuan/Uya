const std = @import("std");

pub fn hex(bytes: []const u8, out: []u8) []const u8 {
    var i: usize = 0;
    while (i < bytes.len) : (i += 1) {
        const b = bytes[i];
        const hi: u8 = b >> 4;
        const lo: u8 = b & 0x0F;
        out[i * 2] = if (hi < 10) ('0' + hi) else ('a' + (hi - 10));
        out[i * 2 + 1] = if (lo < 10) ('0' + lo) else ('a' + (lo - 10));
    }
    return out[0 .. bytes.len * 2];
}

pub fn store(alloc: std.mem.Allocator, root: []const u8, algo: []const u8, data: []const u8) ![]const u8 {
    var h = std.crypto.hash.sha2.Sha256.init(.{});
    h.update(data);
    var sum: [32]u8 = undefined;
    h.final(&sum);
    var hexbuf: [64]u8 = undefined;
    const hexsum = hex(sum[0..], hexbuf[0..]);
    var p = std.fs.cwd();
    const objdir = try std.mem.concat(alloc, u8, &[_][]const u8{ root, "/objects/", algo });
    defer alloc.free(objdir);
    try p.makePath(objdir);
    const dir = try p.openDir(objdir, .{});
    const path = try std.mem.concat(alloc, u8, &[_][]const u8{ hexsum, ".blob" });
    defer alloc.free(path);
    var exists = false;
    if (dir.openFile(path, .{ .mode = .read_only })) |f| { f.close(); exists = true; } else |_| {}
    if (!exists) {
        var f = try dir.createFile(path, .{});
        defer f.close();
        try f.writeAll(data);
    }
    return hexsum;
}