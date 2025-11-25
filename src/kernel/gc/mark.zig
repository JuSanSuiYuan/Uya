const api = @import("gc_api");
const card = @import("gc_card");
var marked: usize = 0;
fn scan(ptr: [*]u8) void {
    const h = api.header(ptr);
    if (h.mark == 0) return;
    const psz: usize = @as(usize, h.size);
    var off: usize = 0;
    while (off + @sizeOf(usize) <= psz) : (off += @sizeOf(usize)) {
        const p = @as(usize, @bitCast(@as(usize, @intFromPtr(@ptrCast(@alignCast(@ptrFromInt(@intFromPtr(ptr) + off))))))));
        if (p >= api.heap_base_get() and p < api.heap_base_get() + api.heap_size_get()) {
            const ph: *api.ObjHeader = @ptrFromInt(p - @sizeOf(api.ObjHeader));
            if (ph.mark == 0) { ph.mark = 1; marked += 1; card.mark(p); }
        }
    }
}
pub fn start_concurrent() void { marked = 0; var i: usize = 0; while (i < card.ncards_get()) : (i += 1) { if (card.is_dirty(i)) {} } }
pub fn step() void { var p = api.first_obj(); while (p) |q| { scan(q); p = api.next_obj(q); } }
pub fn get_marked() usize { return marked; }
