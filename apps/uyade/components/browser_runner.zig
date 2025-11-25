const std = @import("std");

pub fn open_url_and_save(url: []const u8, width: usize, alloc: std.mem.Allocator) void {
    var args = std.ArrayList([]const u8).init(alloc);
    defer args.deinit();
    _ = args.append("uyabrowser");
    _ = args.append("--url");
    _ = args.append(url);
    _ = args.append("--width");
    var wbuf: [32]u8 = undefined;
    const wstr = std.fmt.bufPrint(&wbuf, "{d}", .{width}) catch "80";
    _ = args.append(wstr);
    _ = args.append("--save");
    _ = args.append("registry");
    _ = args.append("org/uya/browser");
    _ = args.append("demo");
    _ = args.append("page.txt");
    var child = std.process.Child.init(args.items, alloc);
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    _ = child.spawn() catch return;
    _ = child.wait() catch {};
}
