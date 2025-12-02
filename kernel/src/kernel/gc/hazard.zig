const api = @import("gc_api");
var hptrs: [256]usize = undefined;
var hn: usize = 0;
pub fn protect(p: [*]u8) void { if (hn < hptrs.len) { hptrs[hn] = @intFromPtr(p); hn += 1; } }
pub fn clear() void { hn = 0; }
pub fn mark_all() void {
    var i: usize = 0;
    while (i < hn) : (i += 1) {
        const addr = hptrs[i];
        if (addr >= api.heap_base_get() and addr < api.heap_base_get() + api.heap_size_get()) {
            const h = api.header(@ptrFromInt(addr));
            h.mark = 1;
        }
    }
}
