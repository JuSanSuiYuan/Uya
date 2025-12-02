const vfs = @import("fs_vfs");
const pe = @import("win_pe");
const abi = @import("zigabi/module.zig");

var names: [8][32]u8 = undefined;
var lens: [8]usize = undefined;
var tabs: [8]*const abi.Table = undefined;
var used: [8]bool = [_]bool{false} ** 8;
pub const Error = enum { none, not_found, bad_abi, no_export };
var last_err: Error = .none;
pub fn last_error() Error { return last_err; }
pub fn last_error_str() []const u8 {
    return switch (last_err) { .none => "none", .not_found => "not_found", .bad_abi => "bad_abi", .no_export => "no_export" };
}

pub fn register(name: []const u8, t: *const abi.Table) bool {
    var i: usize = 0;
    while (i < used.len and used[i]) : (i += 1) {}
    if (i == used.len) return false;
    var j: usize = 0;
    while (j < name.len and j < 32) : (j += 1) names[i][j] = name[j];
    lens[i] = if (name.len < 32) name.len else 32;
    tabs[i] = t;
    used[i] = true;
    return true;
}

fn eq(a: []const u8, b: []const u8) bool { if (a.len != b.len) return false; var i: usize = 0; while (i < a.len) : (i += 1) if (a[i] != b[i]) return false; return true; }

pub fn get(name: []const u8) ?*const abi.Table {
    var i: usize = 0;
    while (i < used.len) : (i += 1) {
        if (used[i]) { const n = names[i][0..lens[i]]; if (eq(n, name)) return tabs[i]; }
    }
    return null;
}

pub fn load(path: []const u8, image_buf: []u8) ?*const abi.Table {
    const data = vfs.UyaFS.read(path) orelse { last_err = .not_found; return null; };
    const mapped = pe.PE.mapImage(data, image_buf);
    const va = pe.PE.exportVa(data, "uya_module");
    if (va == 0) { last_err = .no_export; return null; }
    const tp: *const abi.Table = @ptrFromInt(@as(usize, @intCast(va)));
    if (tp.version != abi.ABI_VERSION) { last_err = .bad_abi; return null; }
    last_err = .none;
    return tp;
}
pub fn register_loaded(name: []const u8, path: []const u8, image_buf: []u8) bool {
    if (load(path, image_buf)) |tp| { return register(name, tp); }
    return false;
}
