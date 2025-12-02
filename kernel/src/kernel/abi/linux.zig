const vfs = @import("fs_vfs");
const events = @import("events");

var used: [32]bool = [_]bool{false} ** 32;
var paths: [32][256]u8 = undefined;
var lens: [32]usize = undefined;

fn open_builtin(code: u64) u64 {
    var p: []const u8 = switch (code) {
        1 => "/etc/motd",
        2 => "/etc/version",
        else => return 0,
    };
    const len: usize = p.len;
    var i: usize = 0;
    while (i < used.len and used[i]) : (i += 1) {}
    if (i == used.len) return 0;
    var k: usize = 0;
    while (k < len) : (k += 1) paths[i][k] = p[k];
    lens[i] = len;
    used[i] = true;
    return @as(u64, i + 3);
}

fn read_fd(fd: u64, max: u64) u64 {
    if (fd < 3) return 0;
    const idx = @as(usize, fd - 3);
    if (idx >= used.len) return 0;
    if (!used[idx]) return 0;
    const p = paths[idx][0..lens[idx]];
    if (vfs.UyaFS.read(p)) |data| {
        const want = @as(usize, if (max > @as(u64, data.len)) @as(u64, data.len) else max);
        const slice = data[0..want];
        _ = events.pushBytes(slice);
        return @as(u64, want);
    }
    return 0;
}

fn close_fd(fd: u64) u64 {
    if (fd < 3) return 0;
    const idx = @as(usize, fd - 3);
    if (idx >= used.len) return 0;
    used[idx] = false;
    lens[idx] = 0;
    return 1;
}

pub fn dispatch(no: u32, a0: u64, a1: u64) u64 {
    return switch (no) {
        1 => open_builtin(a0),
        2 => read_fd(a0, a1),
        3 => close_fd(a0),
        else => 0,
    };
}