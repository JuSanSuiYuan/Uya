const tb = @import("titlebar_layout.zig");
pub const Rect = struct { x: usize, y: usize, w: usize, h: usize, name: []const u8 };
var size_px: usize = 24;
var spacing_px: usize = 8;
pub fn set_metrics(size: usize, spacing: usize) void { size_px = size; spacing_px = spacing; }
pub fn compute(width: usize, height: usize, out_left: []Rect, out_right: []Rect) struct { ln: usize, rn: usize } {
    var x_left: usize = spacing_px;
    var x_right: usize = if (width > spacing_px) width - spacing_px else 0;
    const y: usize = spacing_px;
    var ln: usize = 0;
    var rn: usize = 0;
    const left = tb.get_left();
    const right = tb.get_right();
    var i: usize = 0;
    while (i < left.len and ln < out_left.len) : (i += 1) {
        out_left[ln] = .{ .x = x_left, .y = y, .w = size_px, .h = size_px, .name = left[i] };
        x_left += size_px + spacing_px;
        ln += 1;
    }
    var j: usize = 0;
    while (j < right.len and rn < out_right.len) : (j += 1) {
        const w = size_px;
        if (x_right >= w) x_right -= w else x_right = 0;
        out_right[rn] = .{ .x = x_right, .y = y, .w = size_px, .h = size_px, .name = right[j] };
        if (x_right >= spacing_px) x_right -= spacing_px else x_right = 0;
        rn += 1;
    }
    return .{ .ln = ln, .rn = rn };
}
