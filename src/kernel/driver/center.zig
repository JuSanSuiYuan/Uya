const std = @import("std");
const vfs = @import("fs_vfs");
const zigmod = @import("plugin_zigmod");
const uyl = @import("uyalink");
pub fn port(dev: []const u8, os_src: []const u8, src: []const u8) []const u8 {
    var tlv: [512]u8 = undefined;
    const en = uyl.encode_attrs(&[_]uyl.Attr{ .{ .kind = @intFromEnum(uyl.AttrKind.dev_id), .val = dev }, .{ .kind = @intFromEnum(uyl.AttrKind.os_src), .val = os_src }, .{ .kind = @intFromEnum(uyl.AttrKind.src), .val = src } }, tlv[0..]);
    if (zigmod.get("driver_doubao")) |pd| { _ = pd.call.*(3001, tlv[0..en]); }
    if (zigmod.get("driver_qwen")) |pq| { _ = pq.call.*(3002, tlv[0..en]); }
    if (zigmod.get("driver_hunyuan")) |ph| { _ = ph.call.*(3003, tlv[0..en]); }
    if (vfs.UyaFS.read("/drivers/port/")) |d| { return d; }
    if (vfs.UyaFS.read("/drivers/")) |d2| { return d2; }
    return src;
}
const work = @import("worktree_mod");
fn write_audit(dev: []const u8, action: []const u8, info: []const u8) void {
    const alloc = std.heap.page_allocator;
    const dirp = std.mem.concat(alloc, u8, &[_][]const u8{ "/audit/driver/", dev }) catch return;
    defer alloc.free(dirp);
    var nameb: [64]u8 = undefined;
    var nlen: usize = 0;
    var i: usize = 0;
    while (i < action.len and nlen < nameb.len) : (i += 1) { nameb[nlen] = action[i]; nlen += 1; }
    if (nlen < nameb.len) { nameb[nlen] = '_'; nlen += 1; }
    var j: usize = 0;
    while (j < info.len and nlen < nameb.len) : (j += 1) { nameb[nlen] = info[j]; nlen += 1; }
    const fname = nameb[0..nlen];
    const full = std.mem.concat(alloc, u8, &[_][]const u8{ dirp, "/", fname }) catch return;
    defer alloc.free(full);
    _ = vfs.UyaFS.addFile(full, info);
}
pub fn install(root: []const u8, dev: []const u8, version: []const u8) bool {
    work.ensure(@import("std").heap.page_allocator, root, dev, version) catch return false;
    if (vfs.UyaFS.read("/drivers/port/")) |d| {
        const rel = "driver.zig";
        work.link_or_copy(@import("std").heap.page_allocator, root, "sha256", d, dev, rel, version) catch return false;
        work.switch_current(@import("std").heap.page_allocator, root, dev, version) catch return false;
        write_audit(dev, "install", version);
        return true;
    }
    return false;
}
pub fn verify(dev: []const u8) bool {
    if (vfs.UyaFS.read("/drivers/port/")) |d| {
        var ok: bool = true;
        if (d.len < 12) ok = false;
        write_audit(dev, "verify", if (ok) "ok" else "fail");
        return ok;
    }
    return false;
}
pub fn rollback(root: []const u8, dev: []const u8, version: []const u8) bool {
    const res = work.switch_current(@import("std").heap.page_allocator, root, dev, version) catch false;
    if (res) write_audit(dev, "rollback", version);
    return res;
}
