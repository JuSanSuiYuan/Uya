const fb = @import("framebuffer.zig");

pub const Surface = struct { off: usize, w: usize, h: usize };
var backbuf_off: usize = 0;
var backbuf_w: usize = 0;
var backbuf_h: usize = 0;
const Rect = struct { x: usize, y: usize, w: usize, h: usize };
const MaxLayers = 16;
var layers_s: [MaxLayers]Surface = undefined;
var layers_x: [MaxLayers]usize = undefined;
var layers_y: [MaxLayers]usize = undefined;
var layers_z: [MaxLayers]usize = undefined;
var layers_opaque: [MaxLayers]bool = [_]bool{true} ** MaxLayers;
var layers_used: [MaxLayers]bool = [_]bool{false} ** MaxLayers;
var dirty: [64]Rect = undefined;
var dirty_n: usize = 0;
var rows_copied: u64 = 0;
var bytes_copied: u64 = 0;

pub fn init() void {
    if (fb.FB.addr != 0 and fb.FB.width != 0 and fb.FB.height != 0) {
        const off_opt = fb.FB.allocRect(fb.FB.width, fb.FB.height, 64);
        if (off_opt) |off| { backbuf_off = off; backbuf_w = fb.FB.width; backbuf_h = fb.FB.height; }
    }
    var i: usize = 0; while (i < MaxLayers) : (i += 1) layers_used[i] = false;
    dirty_n = 0;
    rows_copied = 0;
    bytes_copied = 0;
}

pub fn create_surface(w: usize, h: usize) ?Surface {
    const off_opt = fb.FB.allocRect(w, h, 64);
    if (off_opt) |off| return .{ .off = off, .w = w, .h = h };
    return null;
}

pub fn destroy_surface(s: Surface) void { fb.FB.freeRect(s.off, s.w, s.h); }

fn bytes_per_pixel() usize { return fb.FB.bpp / 8; }

pub fn fill_surface(s: Surface, rgba: u32) void {
    const p: [*]u8 = @ptrFromInt(fb.FB.addr + s.off);
    const row = s.w * bytes_per_pixel();
    var line: [4096]u8 = undefined;
    var i: usize = 0;
    while (i < row) : (i += 1) {
        switch (fb.FB.bpp) { 32 => { line[i + 0] = @as(u8, @intCast((rgba >> 0) & 0xFF)); line[i + 1] = @as(u8, @intCast((rgba >> 8) & 0xFF)); line[i + 2] = @as(u8, @intCast((rgba >> 16) & 0xFF)); line[i + 3] = @as(u8, @intCast((rgba >> 24) & 0xFF)); i += 3; }, 24 => { line[i + 0] = @as(u8, @intCast((rgba >> 0) & 0xFF)); line[i + 1] = @as(u8, @intCast((rgba >> 8) & 0xFF)); line[i + 2] = @as(u8, @intCast((rgba >> 16) & 0xFF)); }, else => {} }
    }
    var y: usize = 0;
    while (y < s.h) : (y += 1) {
        const dst = p[y * fb.FB.pitch .. y * fb.FB.pitch + row];
        @memcpy(dst, line[0..row]);
    }
}

pub fn add_layer(s: Surface, x: usize, y: usize, z: usize) ?usize {
    var i: usize = 0;
    while (i < MaxLayers and layers_used[i]) : (i += 1) {}
    if (i == MaxLayers) return null;
    layers_s[i] = s; layers_x[i] = x; layers_y[i] = y; layers_z[i] = z; layers_used[i] = true; return i;
}

pub fn remove_layer(id: usize) void { if (id < MaxLayers and layers_used[id]) layers_used[id] = false; }
pub fn set_layer_opacity(id: usize, opaque: bool) void { if (id < MaxLayers and layers_used[id]) layers_opaque[id] = opaque; }
pub fn reset_metrics() void { rows_copied = 0; bytes_copied = 0; }
pub fn get_rows() u64 { return rows_copied; }
pub fn get_bytes() u64 { return bytes_copied; }

pub fn mark_dirty(x: usize, y: usize, w: usize, h: usize) void {
    if (dirty_n < dirty.len) { dirty[dirty_n] = .{ .x = x, .y = y, .w = w, .h = h }; dirty_n += 1; }
}

fn blit_rect(src_off: usize, sx: usize, sy: usize, dx: usize, dy: usize, w: usize, h: usize) void {
    const sp: [*]u8 = @ptrFromInt(fb.FB.addr + src_off);
    const bp: [*]u8 = @ptrFromInt(fb.FB.addr + backbuf_off);
    const bpp = bytes_per_pixel();
    var y: usize = 0;
    while (y < h) : (y += 1) {
        const srow = sp[(sy + y) * fb.FB.pitch + sx * bpp .. (sy + y) * fb.FB.pitch + (sx + w) * bpp];
        const drow = bp[(dy + y) * fb.FB.pitch + dx * bpp .. (dy + y) * fb.FB.pitch + (dx + w) * bpp];
        @memcpy(drow, srow);
        rows_copied += 1;
        bytes_copied += @as(u64, @intCast(w * bpp));
    }
}

pub fn compose() void {
    var idx: [MaxLayers]usize = undefined;
    var n: usize = 0;
    var i: usize = 0;
    while (i < MaxLayers) : (i += 1) { if (layers_used[i]) { idx[n] = i; n += 1; } }
    var a: usize = 0;
    while (a + 1 < n) : (a += 1) {
        var b: usize = a + 1;
        while (b < n) : (b += 1) {
            if (layers_z[idx[a]] > layers_z[idx[b]]) { const t = idx[a]; idx[a] = idx[b]; idx[b] = t; }
        }
    }
    var k: usize = 0;
    while (k < n) : (k += 1) {
        const id = idx[k];
        blit_rect(layers_s[id].off, 0, 0, layers_x[id], layers_y[id], layers_s[id].w, layers_s[id].h);
    }
}

pub fn compose_dirty() void {
    var i: usize = 0;
    while (i < dirty_n) : (i += 1) {
        var j: usize = i + 1;
        while (j < dirty_n) : (j += 1) {
            const ax0 = dirty[i].x; const ay0 = dirty[i].y;
            const ax1 = dirty[i].x + dirty[i].w; const ay1 = dirty[i].y + dirty[i].h;
            const bx0 = dirty[j].x; const by0 = dirty[j].y;
            const bx1 = dirty[j].x + dirty[j].w; const by1 = dirty[j].y + dirty[j].h;
            const ix0 = if (ax0 > bx0) ax0 else bx0;
            const iy0 = if (ay0 > by0) ay0 else by0;
            const ix1 = if (ax1 < bx1) ax1 else bx1;
            const iy1 = if (ay1 < by1) ay1 else by1;
            const touch_h = (ax1 == bx0 or bx1 == ax0) and (ay0 <= by1 and ay1 >= by0);
            const touch_v = (ay1 == by0 or by1 == ay0) and (ax0 <= bx1 and ax1 >= bx0);
            if ((ix1 >= ix0 and iy1 >= iy0) or touch_h or touch_v) {
                const mx0 = if (ax0 < bx0) ax0 else bx0;
                const my0 = if (ay0 < by0) ay0 else by0;
                const mx1 = if (ax1 > bx1) ax1 else bx1;
                const my1 = if (ay1 > by1) ay1 else by1;
                dirty[i] = .{ .x = mx0, .y = my0, .w = mx1 - mx0, .h = my1 - my0 };
                var k: usize = j;
                while (k + 1 < dirty_n) : (k += 1) dirty[k] = dirty[k + 1];
                dirty_n -= 1;
                j = i + 1;
            }
        }
    }
    var idx: [MaxLayers]usize = undefined;
    var n: usize = 0;
    var li: usize = 0;
    while (li < MaxLayers) : (li += 1) { if (layers_used[li]) { idx[n] = li; n += 1; } }
    var a: usize = 0;
    while (a + 1 < n) : (a += 1) {
        var b: usize = a + 1;
        while (b < n) : (b += 1) {
            if (layers_z[idx[a]] > layers_z[idx[b]]) { const t = idx[a]; idx[a] = idx[b]; idx[b] = t; }
        }
    }
    var r: usize = 0;
    while (r < dirty_n) : (r += 1) {
        var k2: usize = 0;
        while (k2 < n) : (k2 += 1) {
            const id = idx[k2];
            const lb = Rect{ .x = layers_x[id], .y = layers_y[id], .w = layers_s[id].w, .h = layers_s[id].h };
            var base = intersect(dirty[r], lb) orelse continue;
            var parts: [64]Rect = undefined;
            var parts_n: usize = 0;
            parts[0] = base;
            parts_n = 1;
            var k3: usize = k2 + 1;
            while (k3 < n) : (k3 += 1) {
                if (!layers_opaque[idx[k3]]) continue;
                const cover = Rect{ .x = layers_x[idx[k3]], .y = layers_y[idx[k3]], .w = layers_s[idx[k3]].w, .h = layers_s[idx[k3]].h };
                var new_parts: [64]Rect = undefined;
                var new_n: usize = 0;
                var pi: usize = 0;
                while (pi < parts_n) : (pi += 1) {
                    var tmp: [4]Rect = undefined;
                    const got = subtract_one(parts[pi], cover, tmp[0..]);
                    var gi: usize = 0;
                    while (gi < got and new_n < new_parts.len) : (gi += 1) { new_parts[new_n] = tmp[gi]; new_n += 1; }
                }
                var ci: usize = 0; while (ci < new_n) : (ci += 1) parts[ci] = new_parts[ci];
                parts_n = new_n;
                if (parts_n == 0) break;
            }
            var oi: usize = 0;
            while (oi < parts_n) : (oi += 1) {
                const ix0 = parts[oi].x; const iy0 = parts[oi].y; const ix1 = parts[oi].x + parts[oi].w; const iy1 = parts[oi].y + parts[oi].h;
                const sx = ix0 - lb.x; const sy = iy0 - lb.y;
                const dx = ix0; const dy = iy0;
                blit_rect(layers_s[id].off, sx, sy, dx, dy, ix1 - ix0, iy1 - iy0);
            }
        }
    }
}

pub fn blit(s: Surface, sx: usize, sy: usize, dx: usize, dy: usize, w: usize, h: usize) void {
    const sp: [*]u8 = @ptrFromInt(fb.FB.addr + s.off);
    const bp: [*]u8 = @ptrFromInt(fb.FB.addr + backbuf_off);
    const bpp = bytes_per_pixel();
    var y: usize = 0;
    while (y < h) : (y += 1) {
        const srow = sp[(sy + y) * fb.FB.pitch + sx * bpp .. (sy + y) * fb.FB.pitch + (sx + w) * bpp];
        const drow = bp[(dy + y) * fb.FB.pitch + dx * bpp .. (dy + y) * fb.FB.pitch + (dx + w) * bpp];
        @memcpy(drow, srow);
    }
}

pub fn present() void {
    if (backbuf_off == 0) return;
    const src: [*]u8 = @ptrFromInt(fb.FB.addr + backbuf_off);
    const dst: [*]u8 = @ptrFromInt(fb.FB.addr);
    var y: usize = 0;
    const row = fb.FB.width * bytes_per_pixel();
    while (y < fb.FB.height) : (y += 1) {
        const s = src[y * fb.FB.pitch .. y * fb.FB.pitch + row];
        const d = dst[y * fb.FB.pitch .. y * fb.FB.pitch + row];
        @memcpy(d, s);
        rows_copied += 1;
        bytes_copied += @as(u64, @intCast(row));
    }
}

pub fn present_dirty() void {
    if (backbuf_off == 0) return;
    const src: [*]u8 = @ptrFromInt(fb.FB.addr + backbuf_off);
    const dst: [*]u8 = @ptrFromInt(fb.FB.addr);
    var r: usize = 0;
    const bpp = bytes_per_pixel();
    while (r < dirty_n) : (r += 1) {
        var y: usize = 0;
        while (y < dirty[r].h) : (y += 1) {
            const s = src[(dirty[r].y + y) * fb.FB.pitch + dirty[r].x * bpp .. (dirty[r].y + y) * fb.FB.pitch + (dirty[r].x + dirty[r].w) * bpp];
            const d = dst[(dirty[r].y + y) * fb.FB.pitch + dirty[r].x * bpp .. (dirty[r].y + y) * fb.FB.pitch + (dirty[r].x + dirty[r].w) * bpp];
            @memcpy(d, s);
            rows_copied += 1;
            bytes_copied += @as(u64, @intCast(dirty[r].w * bpp));
        }
    }
    dirty_n = 0;
}

fn intersect(a: Rect, b: Rect) ?Rect {
    const x0 = if (a.x > b.x) a.x else b.x;
    const y0 = if (a.y > b.y) a.y else b.y;
    const x1 = if ((a.x + a.w) < (b.x + b.w)) (a.x + a.w) else (b.x + b.w);
    const y1 = if ((a.y + a.h) < (b.y + b.h)) (a.y + a.h) else (b.y + b.h);
    if (x1 <= x0 or y1 <= y0) return null;
    return .{ .x = x0, .y = y0, .w = x1 - x0, .h = y1 - y0 };
}

fn subtract_one(r: Rect, cover: Rect, out: []Rect) usize {
    const ip = intersect(r, cover) orelse return blk: {
        out[0] = r;
        break :blk 1;
    };
    var n: usize = 0;
    if (ip.y > r.y) { out[n] = .{ .x = r.x, .y = r.y, .w = r.w, .h = ip.y - r.y }; n += 1; }
    const ip_bottom = ip.y + ip.h;
    const r_bottom = r.y + r.h;
    if (ip_bottom < r_bottom) { out[n] = .{ .x = r.x, .y = ip_bottom, .w = r.w, .h = r_bottom - ip_bottom }; n += 1; }
    if (ip.x > r.x) { out[n] = .{ .x = r.x, .y = ip.y, .w = ip.x - r.x, .h = ip.h }; n += 1; }
    const ip_right = ip.x + ip.w;
    const r_right = r.x + r.w;
    if (ip_right < r_right) { out[n] = .{ .x = ip_right, .y = ip.y, .w = r_right - ip_right, .h = ip.h }; n += 1; }
    return n;
}
