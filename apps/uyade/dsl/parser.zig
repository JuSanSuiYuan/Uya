const std = @import("std");

pub const Key = struct { sec: []const u8, key: []const u8 };
pub const Value = union(enum) { s: []const u8, b: bool, arrs: [][]const u8 };
pub const Item = struct { k: Key, v: Value };

pub const Doc = struct {
    items: []Item,
};

pub fn parse(alloc: std.mem.Allocator, src: []const u8) !Doc {
    var list = std.ArrayListUnmanaged(Item){};
    var it = std.mem.splitScalar(u8, src, '\n');
    var cur_sec: []const u8 = "";
    while (it.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        if (line[0] == '[' and line[line.len-1] == ']') {
            cur_sec = std.mem.trim(u8, line[1..line.len-1], " \t");
            continue;
        }
        const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const k = std.mem.trim(u8, line[0..eq], " \t");
        var vraw = std.mem.trim(u8, line[eq+1..], " \t");
        var v: Value = undefined;
        if (vraw.len >= 2 and vraw[0] == '[' and vraw[vraw.len-1] == ']') {
            const inner = std.mem.trim(u8, vraw[1..vraw.len-1], " \t");
            var parts = std.ArrayListUnmanaged([]const u8){};
            var it2 = std.mem.splitScalar(u8, inner, ',');
            while (it2.next()) |tok_raw| {
                const tok = std.mem.trim(u8, tok_raw, " \t");
                if (tok.len >= 2 and tok[0] == '"' and tok[tok.len-1] == '"') {
                    const sv = tok[1..tok.len-1];
                    try parts.append(alloc, sv);
                }
            }
            const slice = try parts.toOwnedSlice(alloc);
            v = .{ .arrs = slice };
        } else if (vraw.len >= 2 and vraw[0] == '"' and vraw[vraw.len-1] == '"') {
            v = .{ .s = vraw[1..vraw.len-1] };
        } else if (std.mem.eql(u8, vraw, "true") or std.mem.eql(u8, vraw, "false")) {
            v = .{ .b = std.mem.eql(u8, vraw, "true") };
        } else {
            v = .{ .s = vraw };
        }
        try list.append(alloc, .{ .k = .{ .sec = cur_sec, .key = k }, .v = v });
    }
    return .{ .items = try list.toOwnedSlice(alloc) };
}

pub fn findString(doc: *const Doc, sec: []const u8, key: []const u8) ?[]const u8 {
    var i: usize = 0;
    while (i < doc.items.len) : (i += 1) {
        const it = doc.items[i];
        if (std.mem.eql(u8, it.k.sec, sec) and std.mem.eql(u8, it.k.key, key)) {
            if (it.v == .s) return it.v.s;
        }
    }
    return null;
}

pub fn findBool(doc: *const Doc, sec: []const u8, key: []const u8) ?bool {
    var i: usize = 0;
    while (i < doc.items.len) : (i += 1) {
        const it = doc.items[i];
        if (std.mem.eql(u8, it.k.sec, sec) and std.mem.eql(u8, it.k.key, key)) {
            if (it.v == .b) return it.v.b;
        }
    }
    return null;
}

pub fn findStringArray(doc: *const Doc, sec: []const u8, key: []const u8) ?[][]const u8 {
    var i: usize = 0;
    while (i < doc.items.len) : (i += 1) {
        const it = doc.items[i];
        if (std.mem.eql(u8, it.k.sec, sec) and std.mem.eql(u8, it.k.key, key)) {
            if (it.v == .arrs) return it.v.arrs;
        }
    }
    return null;
}