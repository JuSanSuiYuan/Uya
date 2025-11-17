const std = @import("std");

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);
    var log = try std.fs.cwd().createFile("registry_audit.log", .{});
    defer log.close();
    try log.writeAll("start\n");
    var sha = std.crypto.hash.sha2.Sha256.init(.{});
    sha.update("sign");
    var sum: [32]u8 = undefined;
    sha.final(&sum);
    try log.writeAll("sig\n");
    var i: usize = 0;
    while (i < 3) : (i += 1) {
        try log.writeAll("tick\n");
    }
}