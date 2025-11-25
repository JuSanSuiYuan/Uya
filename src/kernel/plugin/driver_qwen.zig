const abi = @import("zigabi/module.zig");
const uyl = @import("uyalink");
const vfs = @import("fs_vfs");
fn call_impl(_: u64, data: []const u8) usize {
    var attrs: [4]uyl.Attr = undefined;
    const n = uyl.decode_attrs(data, attrs[0..]);
    var dev: []const u8 = "dev";
    var src: []const u8 = "";
    var i: usize = 0; while (i < n) : (i += 1) { if (attrs[i].kind == @intFromEnum(uyl.AttrKind.dev_id)) dev = attrs[i].val; if (attrs[i].kind == @intFromEnum(uyl.AttrKind.src)) src = attrs[i].val; }
    var out: []const u8 = "pub fn start() void {}";
    if (src.len > 0) out = src[0..src.len];
    _ = vfs.UyaFS.addFile("/drivers/" ++ dev ++ "/qwen.zig", out);
    _ = vfs.UyaFS.addFile("/drivers/port/", out);
    return out.len;
}
fn init_impl() void {}
fn fini_impl() void {}
var tbl: abi.Table = .{ .version = abi.ABI_VERSION, .init = &init_impl, .fini = &fini_impl, .call = &call_impl };
pub fn get_table() *const abi.Table { return &tbl; }
