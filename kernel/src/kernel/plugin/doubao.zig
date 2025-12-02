const abi = @import("zigabi/module.zig");
const uyl = @import("uyalink");
const vfs = @import("fs_vfs");
const gen = @import("ai_doubao");

fn call_impl(id: u64, data: []const u8) usize {
    _ = id;
    var attrs: [4]uyl.Attr = undefined;
    const n = uyl.decode_attrs(data, attrs[0..]);
    var prompt: []const u8 = "";
    var lang: []const u8 = "zig";
    var i: usize = 0;
    while (i < n) : (i += 1) {
        if (attrs[i].kind == @intFromEnum(uyl.AttrKind.prompt)) prompt = attrs[i].val;
        if (attrs[i].kind == @intFromEnum(uyl.AttrKind.lang)) lang = attrs[i].val;
    }
    const code = gen.gen(prompt, lang);
    _ = vfs.UyaFS.addFile("/seed/code.zig", code);
    return code.len;
}

var tbl: abi.Table = .{ .version = abi.ABI_VERSION, .init = &init_impl, .fini = &fini_impl, .call = &call_impl };
fn init_impl() void {}
fn fini_impl() void {}
pub fn get_table() *const abi.Table { return &tbl; }
