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
    } else if (std.mem.eql(u8, cmd, "put-file")) {
        if (args.len < 4) return;
        const root = args[2];
        const path = args[3];
        const buf = try std.fs.cwd().readFileAlloc(path, gpa, @enumFromInt(1 << 24));
        defer gpa.free(buf);
        const hexsum = try cas.store(gpa, root, "sha256", buf);
        std.debug.print("{s}\n", .{ hexsum });
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
    } else if (std.mem.eql(u8, cmd, "switch")) {
        if (args.len < 5) return;
        const root = args[2];
        const prefix = args[3];
        const version = args[4];
        try wt.switch_current(gpa, root, prefix, version);
    }
}