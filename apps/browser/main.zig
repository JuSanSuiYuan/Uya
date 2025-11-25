const std = @import("std");
const worktree = @import("worktree_mod");

fn usage() void {
    const o = std.io.getStdOut().writer();
    _ = o.print("uyabrowser --url <URL> [--width <N>] [--extract-links] [--follow <IDX>] [--save <root> <name> <version> <rel>]\n", .{});
}

fn fetch(alloc: std.mem.Allocator, url: []const u8) ![]u8 {
    var client = std.http.Client.init(alloc);
    defer client.deinit();
    var req = try client.request(.GET, std.Uri.parse(url) catch return error.Invalid, .{}, .{});
    try req.start(.{});
    try req.wait();
    return try req.reader().readAllAlloc(alloc, 8 * 1024 * 1024);
}

fn strip_html(alloc: std.mem.Allocator, html: []const u8) ![]u8 {
    var out = try alloc.alloc(u8, html.len);
    var i: usize = 0;
    var j: usize = 0;
    var in_tag: bool = false;
    while (i < html.len) : (i += 1) {
        const c = html[i];
        if (c == '<') { in_tag = true; continue; }
        if (c == '>') { in_tag = false; continue; }
        if (!in_tag) { out[j] = if (c == '\r') ' ' else c; j += 1; }
    }
    return out[0..j];
}

fn wrap_text(alloc: std.mem.Allocator, text: []const u8, width: usize) ![]u8 {
    if (width == 0) return text;
    var out = try alloc.alloc(u8, text.len * 2);
    var j: usize = 0;
    var col: usize = 0;
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        const c = text[i];
        if (c == '\n') { out[j] = c; j += 1; col = 0; continue; }
        if (col >= width and c == ' ') { out[j] = '\n'; j += 1; col = 0; continue; }
        out[j] = c; j += 1; col += 1;
    }
    return out[0..j];
}

fn extract_links(alloc: std.mem.Allocator, html: []const u8) ![][]const u8 {
    var links = try alloc.alloc([]const u8, 0);
    var i: usize = 0;
    while (i < html.len) : (i += 1) {
        if (html[i] == 'h' and i + 7 < html.len) {
            const pre = html[i .. std.math.min(i + 8, html.len)];
            if (std.mem.startsWith(u8, pre, "href=\"")) {
                var k: usize = i + 6;
                var start: usize = k;
                while (k < html.len and html[k] != '"') : (k += 1) {}
                const url = html[start .. k];
                const new_len = links.len + 1;
                var tmp = try alloc.realloc(links, new_len);
                links = tmp;
                links[new_len - 1] = url;
                i = k;
            }
        }
    }
    return links;
}

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    var it = try std.process.argsWithAllocator(alloc);
    defer it.deinit();
    _ = it.next();
    const flag = it.next() orelse { usage(); return; };
    if (!std.mem.eql(u8, flag, "--url")) { usage(); return; }
    const url = it.next() orelse { usage(); return; };
    const body = try fetch(alloc, url);
    defer alloc.free(body);
    var text = try strip_html(alloc, body);
    defer alloc.free(text);
    var width: usize = 80;
    var do_extract: bool = false;
    var follow_idx_opt: ?usize = null;
    var opt = it.next();
    while (opt) |flag| {
        if (std.mem.eql(u8, flag, "--width")) { const w = it.next() orelse { usage(); return; }; width = std.fmt.parseInt(usize, w, 10) catch 80; }
        else if (std.mem.eql(u8, flag, "--extract-links")) { do_extract = true; }
        else if (std.mem.eql(u8, flag, "--follow")) { const idxs = it.next() orelse { usage(); return; }; follow_idx_opt = std.fmt.parseInt(usize, idxs, 10) catch null; }
        else break;
        opt = it.next();
    }
    const wrapped = try wrap_text(alloc, text, width);
    defer alloc.free(wrapped);
    const out = std.io.getStdOut().writer();
    _ = out.print("URL {s}\n", .{ url });
    _ = out.print("CONTENT\n", .{});
    _ = out.print("{s}\n", .{ wrapped });
    if (do_extract or follow_idx_opt != null) {
        const links = try extract_links(alloc, body);
        defer alloc.free(links);
        var li: usize = 0;
        while (li < links.len) : (li += 1) { _ = out.print("[{d}] {s}\n", .{ li, links[li] }); }
        if (follow_idx_opt) |fi| {
            if (fi < links.len) {
                const nxt = links[fi];
                const nxt_body = try fetch(alloc, nxt);
                defer alloc.free(nxt_body);
                var nxt_text = try strip_html(alloc, nxt_body);
                defer alloc.free(nxt_text);
                const nxt_wrapped = try wrap_text(alloc, nxt_text, width);
                defer alloc.free(nxt_wrapped);
                _ = out.print("FOLLOW {s}\n", .{ nxt });
                _ = out.print("{s}\n", .{ nxt_wrapped });
            }
        }
    }
    const save_flag = opt;
    if (save_flag) |sf| {
        if (std.mem.eql(u8, sf, "--save")) {
            const root = it.next() orelse { usage(); return; };
            const name = it.next() orelse { usage(); return; };
            const version = it.next() orelse { usage(); return; };
            const rel = it.next() orelse { usage(); return; };
            try worktree.ensure(alloc, root, name, version);
            var p = std.fs.cwd();
            const wdir = try std.mem.concat(alloc, u8, &[_][]const u8{ root, "/worktrees/", name, "/", version });
            defer alloc.free(wdir);
            const dst = try std.mem.concat(alloc, u8, &[_][]const u8{ wdir, "/", rel });
            defer alloc.free(dst);
            var f = try p.createFile(dst, .{});
            defer f.close();
            try f.writeAll(wrapped);
            try worktree.switch_current(alloc, root, name, version);
        }
    }
}
