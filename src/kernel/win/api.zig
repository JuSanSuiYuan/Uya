const vfs = @import("fs_vfs");
const h = @import("win_handle");
const obj = @import("win_object");

const Max = 32;
var paths: [Max][256]u8 = undefined;
var lens: [Max]usize = undefined;
var used: [Max]bool = undefined;

pub fn CreateFileA(path: []const u8) ?h.Handle {
    var buf: [256]u8 = undefined;
    var len: usize = 0;
    while (len < path.len and len < 256) : (len += 1) buf[len] = path[len];
    if (vfs.UyaFS.read(buf[0..len]) == null) return null;
    const hnd = obj.create_file(buf[0..len]) orelse return null;
    return hnd;
}

pub fn ReadAllA(handle: h.Handle) ?[]const u8 {
    if (obj.get_file(handle)) |p| {
        if (vfs.UyaFS.read(p)) |data| return data;
    }
    return null;
}

pub fn CloseHandle(handle: h.Handle) bool {
    return obj.destroy(handle);
}

pub fn GetFileSize(handle: h.Handle) usize {
    if (obj.get_file(handle)) |p| {
        if (vfs.UyaFS.size(p)) |sz| return sz;
    }
    return 0;
}