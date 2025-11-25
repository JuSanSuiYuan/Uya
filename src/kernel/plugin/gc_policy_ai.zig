const abi = @import("zigabi/module.zig");
const uyl = @import("uyalink");
fn call_impl(_: u64, data: []const u8) usize {
    var attrs: [4]uyl.Attr = undefined;
    const n = uyl.decode_attrs(data, attrs[0..]);
    var pause: usize = 0;
    var marked: usize = 0;
    var roots: usize = 0;
    var pinned: usize = 0;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const a = attrs[i];
        if (a.val.len >= 2) {
            const v = @as(usize, a.val[0]) | (@as(usize, a.val[1]) << 8);
            if (a.kind == 1) pause = v;
            if (a.kind == 2) marked = v;
            if (a.kind == 3) roots = v;
            if (a.kind == 4) pinned = v;
        }
    }
    var quota: usize = 8;
    if (pause > 200) quota = 4;
    if (pause < 50 and marked < 128) quota = 16;
    if (roots > 256) quota = if (quota > 2) quota - 1 else 1;
    if (pinned > 128) quota = if (quota > 2) quota - 1 else 1;
    return quota;
}
fn init_impl() void {}
fn fini_impl() void {}
var tbl: abi.Table = .{ .version = abi.ABI_VERSION, .init = &init_impl, .fini = &fini_impl, .call = &call_impl };
pub fn get_table() *const abi.Table { return &tbl; }
