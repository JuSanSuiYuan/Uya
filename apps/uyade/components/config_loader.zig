const std = @import("std");
const taskbar = @import("taskbar.zig");
const settings = @import("settings.zig");
const theme = @import("../theme.zig");

fn readAll(p: []const u8, alloc: std.mem.Allocator) ?[]u8 {
    if (std.fs.cwd().readFileAlloc(p, alloc, @enumFromInt(1 << 20))) |buf| {
        return buf;
    } else |_| return null;
}

fn trimNewline(s: []u8) []u8 {
    var n = s.len;
    while (n > 0 and (s[n-1] == '\n' or s[n-1] == '\r')) : (n -= 1) {}
    return s[0..n];
}

fn parseAccent(s: []const u8) theme.Accent {
    if (std.mem.eql(u8, s, "pink")) return .pink;
    if (std.mem.eql(u8, s, "sky")) return .sky;
    if (std.mem.eql(u8, s, "mint")) return .mint;
    return .pink;
}

fn parseBool(s: []const u8) bool { return std.mem.eql(u8, s, "true"); }

fn parseOrientation(s: []const u8) taskbar.Orientation {
    if (std.mem.eql(u8, s, "bottom")) return .bottom;
    if (std.mem.eql(u8, s, "top")) return .top;
    if (std.mem.eql(u8, s, "left")) return .left;
    if (std.mem.eql(u8, s, "right")) return .right;
    return .bottom;
}

pub fn load(root: []const u8, prefix: []const u8, alloc: std.mem.Allocator) settings.Settings {
    var prefs = settings.Settings.init();
    const curp = std.mem.concat(alloc, u8, &[_][]const u8{ root, "/worktrees/", prefix, "/current" }) catch return prefs;
    defer alloc.free(curp);
    const verbuf_opt = readAll(curp, alloc);
    if (verbuf_opt == null) return prefs;
    const verbuf = verbuf_opt.?;
    defer alloc.free(verbuf);
    const version = trimNewline(verbuf);
    const base = std.mem.concat(alloc, u8, &[_][]const u8{ root, "/worktrees/", prefix, "/" }) catch return prefs;
    defer alloc.free(base);
    const vdir = std.mem.concat(alloc, u8, &[_][]const u8{ base, version }) catch return prefs;
    defer alloc.free(vdir);

    const p_accent = std.mem.concat(alloc, u8, &[_][]const u8{ vdir, "/accent" }) catch vdir;
    const p_orient = std.mem.concat(alloc, u8, &[_][]const u8{ vdir, "/taskbar_orientation" }) catch vdir;
    const p_hsec = std.mem.concat(alloc, u8, &[_][]const u8{ vdir, "/clock_horizontal_seconds" }) catch vdir;
    const p_vsec = std.mem.concat(alloc, u8, &[_][]const u8{ vdir, "/clock_vertical_seconds" }) catch vdir;
    defer alloc.free(p_accent);
    defer alloc.free(p_orient);
    defer alloc.free(p_hsec);
    defer alloc.free(p_vsec);

    if (readAll(p_accent, alloc)) |acc| {
        const v = trimNewline(acc);
        prefs.accent = parseAccent(v);
        alloc.free(acc);
    }
    if (readAll(p_orient, alloc)) |ori| {
        const v = trimNewline(ori);
        prefs.bar_orientation = parseOrientation(v);
        alloc.free(ori);
    }
    if (readAll(p_hsec, alloc)) |hs| {
        const v = trimNewline(hs);
        prefs.horiz_seconds = parseBool(v);
        alloc.free(hs);
    }
    if (readAll(p_vsec, alloc)) |vs| {
        const v = trimNewline(vs);
        prefs.vert_seconds = parseBool(v);
        alloc.free(vs);
    }
    return prefs;
}