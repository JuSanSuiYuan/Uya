const std = @import("std");
const tb = @import("titlebar_layout.zig");
const calc = @import("titlebar_calc.zig");
pub fn render_with_size(width: usize, height: usize) void {
    const o = std.io.getStdOut().writer();
    const left = tb.get_left();
    const right = tb.get_right();
    _ = o.print("TITLEBAR {s}\n", .{ if (tb.get() == .apple) "apple" else "windows" });
    _ = o.print("LEFT ", .{});
    var i: usize = 0; while (i < left.len) : (i += 1) { _ = o.print("{s} ", .{ left[i] }); }
    _ = o.print("\nRIGHT ", .{});
    var j: usize = 0; while (j < right.len) : (j += 1) { _ = o.print("{s} ", .{ right[j] }); }
    _ = o.print("\n", .{});
    var lrects: [16]calc.Rect = undefined;
    var rrects: [16]calc.Rect = undefined;
    const res = calc.compute(width, height, lrects[0..], rrects[0..]);
    _ = o.print("COORDS LEFT\n", .{});
    var k: usize = 0; while (k < res.ln) : (k += 1) { const r = lrects[k]; _ = o.print("{s} @ ({d},{d}) {d}x{d}\n", .{ r.name, r.x, r.y, r.w, r.h }); }
    _ = o.print("COORDS RIGHT\n", .{});
    var m: usize = 0; while (m < res.rn) : (m += 1) { const rr = rrects[m]; _ = o.print("{s} @ ({d},{d}) {d}x{d}\n", .{ rr.name, rr.x, rr.y, rr.w, rr.h }); }
}
pub fn render_ascii(width: usize, height: usize) void {
    var lrects: [16]calc.Rect = undefined;
    var rrects: [16]calc.Rect = undefined;
    const res = calc.compute(width, height, lrects[0..], rrects[0..]);
    const bar_w = width;
    var line = std.heap.page_allocator.alloc(u8, bar_w) catch return;
    defer std.heap.page_allocator.free(line);
    var i: usize = 0; while (i < bar_w) : (i += 1) line[i] = '-';
    const o = std.io.getStdOut().writer();
    var k: usize = 0;
    while (k < res.ln) : (k += 1) {
        const r = lrects[k];
        if (r.x < bar_w) line[r.x] = '[';
        if (r.x + 1 < bar_w) line[r.x + 1] = @as(u8, if (r.name.len > 0) r.name[0] else ' ');
        if (r.x + 2 < bar_w) line[r.x + 2] = ']';
    }
    var m: usize = 0;
    while (m < res.rn) : (m += 1) {
        const rr = rrects[m];
        const pos = if (rr.x + 2 < bar_w) rr.x else if (bar_w > 3) bar_w - 3 else 0;
        line[pos] = '[';
        if (pos + 1 < bar_w) line[pos + 1] = @as(u8, if (rr.name.len > 0) rr.name[0] else ' ');
        if (pos + 2 < bar_w) line[pos + 2] = ']';
    }
    _ = o.print("ASCII TITLEBAR\n", .{});
    _ = o.print("{s}\n", .{ line });
}
