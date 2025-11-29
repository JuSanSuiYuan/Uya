const std = @import("std");
const cas = @import("cas.zig");
const wt = @import("worktree_mod");

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    var args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);
    if (args.len < 2) return;
    const cmd = args[1];
    if (std.mem.eql(u8, cmd, "put")) {
        if (args.len < 4) return;
        const root = args[2];
        const data = args[3];
        const hexsum = try cas.store(gpa, root, "sha256", data);
        std.debug.print("{s}\n", .{ hexsum });
        var p = std.fs.cwd();
        try p.makePath("db/registry");
        var f = try p.openFile("db/registry/kv.log", .{ .mode = .read_write });
        defer f.close();
        _ = try f.seekFromEnd(0);
        try f.writeAll(hexsum);
        try f.writeAll("\n");
    } else if (std.mem.eql(u8, cmd, "put-file")) {
        if (args.len < 4) return;
        const root = args[2];
        const path = args[3];
        const buf = try std.fs.cwd().readFileAlloc(path, gpa, @enumFromInt(1 << 24));
        defer gpa.free(buf);
        const hexsum = try cas.store(gpa, root, "sha256", buf);
        std.debug.print("{s}\n", .{ hexsum });
        var p2 = std.fs.cwd();
        try p2.makePath("db/registry");
        var f2 = try p2.openFile("db/registry/kv.log", .{ .mode = .read_write });
        defer f2.close();
        _ = try f2.seekFromEnd(0);
        try f2.writeAll(hexsum);
        try f2.writeAll("\n");
    } else if (std.mem.eql(u8, cmd, "link")) {
        if (args.len < 8) return;
        const root = args[2];
        const algo = args[3];
        const hash_hex = args[4];
        const prefix = args[5];
        const rel = args[6];
        const version = args[7];
        try wt.ensure(gpa, root, prefix, version);
        try wt.link_or_copy(gpa, root, algo, hash_hex, prefix, rel, version);
        var p3 = std.fs.cwd();
        try p3.makePath("db/registry");
        var f3 = try p3.openFile("db/registry/worktree.log", .{ .mode = .read_write });
        defer f3.close();
        _ = try f3.seekFromEnd(0);
        try f3.writeAll(prefix);
        try f3.writeAll(" ");
        try f3.writeAll(version);
        try f3.writeAll(" ");
        try f3.writeAll(rel);
        try f3.writeAll("\n");
    } else if (std.mem.eql(u8, cmd, "switch")) {
        if (args.len < 5) return;
        const root = args[2];
        const prefix = args[3];
        const version = args[4];
        try wt.switch_current(gpa, root, prefix, version);
        var p4 = std.fs.cwd();
        try p4.makePath("db/registry");
        var f4 = try p4.openFile("db/registry/switch.log", .{ .mode = .read_write });
        defer f4.close();
        _ = try f4.seekFromEnd(0);
        try f4.writeAll(prefix);
        try f4.writeAll(" ");
        try f4.writeAll(version);
        try f4.writeAll("\n");
    }
}
