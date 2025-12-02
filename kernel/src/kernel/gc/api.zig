const mm = @import("mm_core");
const cap_epoch = @import("cap_epoch");
const events = @import("events");

pub const ObjHeader = extern struct { mark: u8, gen: u8, flags: u16, size: u32 };

var heap_base: usize = 0;
var heap_size: usize = 0;
var alloc_ptr: usize = 0;
var nursery_size_cfg: usize = 256 * 1024;
var gen_total: usize = 0;
var obj_total: usize = 0;
pub fn heap_base_get() usize { return heap_base; }
pub fn heap_size_get() usize { return heap_size; }

var roots_ptrs: [128]usize = undefined;
var roots_lens: [128]usize = undefined;
var roots_n: usize = 0;

pub fn init(bytes: usize) void {
    heap_base = 0x40000000;
    heap_size = bytes;
    alloc_ptr = heap_base;
    _ = mm.mm_map(undefined, heap_base, heap_base, bytes, .rw);
    roots_n = 0;
    @import("gc_card").init(heap_base, heap_size, 64);
}

fn align16(n: usize) usize { return (n + 15) & ~@as(usize, 15); }

pub fn alloc(size: usize) ?[*]u8 {
    const need = align16(@sizeOf(ObjHeader) + size);
    if (alloc_ptr + need > heap_base + heap_size) return null;
    const p = alloc_ptr;
    const h: *ObjHeader = @ptrFromInt(p);
    h.mark = 0;
    h.gen = 0;
    h.flags = 0;
    h.size = @as(u32, @intCast(size));
    alloc_ptr += need;
    const payload: [*]u8 = @ptrFromInt(p + @sizeOf(ObjHeader));
    return payload;
}

pub fn alloc_pinned(size: usize) ?[*]u8 {
    const need = align16(@sizeOf(ObjHeader) + size);
    if (alloc_ptr + need > heap_base + heap_size) return null;
    const p = alloc_ptr;
    const h: *ObjHeader = @ptrFromInt(p);
    h.mark = 0;
    h.gen = 0;
    h.flags = 1;
    h.size = @as(u32, @intCast(size));
    alloc_ptr += need;
    const payload: [*]u8 = @ptrFromInt(p + @sizeOf(ObjHeader));
    return payload;
}

pub fn header(ptr: [*]u8) *ObjHeader { return @ptrFromInt(@intFromPtr(ptr) - @sizeOf(ObjHeader)); }

pub fn register_root(ptr: [*]u8, len: usize) void {
    if (roots_n < roots_ptrs.len) {
        roots_ptrs[roots_n] = @intFromPtr(ptr);
        roots_lens[roots_n] = len;
        roots_n += 1;
    }
}

pub fn unregister_root(ptr: [*]u8) void {
    const addr = @intFromPtr(ptr);
    var i: usize = 0;
    while (i < roots_n) : (i += 1) {
        if (roots_ptrs[i] == addr) {
            var j: usize = i;
            while (j + 1 < roots_n) : (j += 1) {
                roots_ptrs[j] = roots_ptrs[j + 1];
                roots_lens[j] = roots_lens[j + 1];
            }
            roots_n -= 1;
            break;
        }
    }
}

pub fn start() void {
    const tok = cap_epoch.enter();
    var i: usize = 0;
    while (i < roots_n) : (i += 1) {
        var off: usize = 0;
        while (off + @sizeOf(usize) <= roots_lens[i]) : (off += @sizeOf(usize)) {
            const p = @as(usize, @bitCast(@as(usize, @intFromPtr(@ptrCast(@alignCast(@ptrFromInt(roots_ptrs[i] + off))))))));
            if (p >= heap_base and p < heap_base + heap_size) {
                const h: *ObjHeader = @ptrFromInt(p - @sizeOf(ObjHeader));
                h.mark = 1;
            }
        }
    }
    @import("gc_hazard").mark_all();
    cap_epoch.exit(tok);
}

pub fn end_cycle() void {
    gen_total = 0;
    obj_total = 0;
    var p = first_obj();
    while (p) |q| {
        const h: *ObjHeader = @ptrFromInt(@intFromPtr(q) - @sizeOf(ObjHeader));
        if (h.mark != 0) { if (h.gen < 255) h.gen += 1; }
        h.mark = 0;
        obj_total += 1;
        gen_total += @as(usize, h.gen);
        p = next_obj(q);
    }
}

pub fn set_nursery_size(n: usize) void { nursery_size_cfg = n; }
pub fn get_nursery_size() usize { return nursery_size_cfg; }
pub fn get_gen_avg() usize { return if (obj_total == 0) 0 else gen_total / obj_total; }

pub fn stats(buf: []u8) usize {
    var w: usize = 0;
    const used = alloc_ptr - heap_base;
    if (buf.len >= 16) {
        buf[w + 0] = @as(u8, @intCast((used >> 0) & 0xFF));
        buf[w + 1] = @as(u8, @intCast((used >> 8) & 0xFF));
        buf[w + 2] = @as(u8, @intCast((used >> 16) & 0xFF));
        buf[w + 3] = @as(u8, @intCast((used >> 24) & 0xFF));
        buf[w + 4] = @as(u8, @intCast((heap_size >> 0) & 0xFF));
        buf[w + 5] = @as(u8, @intCast((heap_size >> 8) & 0xFF));
        buf[w + 6] = @as(u8, @intCast((heap_size >> 16) & 0xFF));
        buf[w + 7] = @as(u8, @intCast((heap_size >> 24) & 0xFF));
        const mk = @import("gc_mark").get_marked();
        buf[w + 8] = @as(u8, @intCast((mk >> 0) & 0xFF));
        buf[w + 9] = @as(u8, @intCast((mk >> 8) & 0xFF));
        buf[w + 10] = @as(u8, @intCast((mk >> 16) & 0xFF));
        buf[w + 11] = @as(u8, @intCast((mk >> 24) & 0xFF));
        const rc = roots_n;
        buf[w + 12] = @as(u8, @intCast((rc >> 0) & 0xFF));
        buf[w + 13] = @as(u8, @intCast((rc >> 8) & 0xFF));
        const pinned = count_pinned();
        buf[w + 14] = @as(u8, @intCast((pinned >> 0) & 0xFF));
        buf[w + 15] = @as(u8, @intCast((pinned >> 8) & 0xFF));
        w = 16;
    }
    return w;
}

pub fn first_obj() ?[*]u8 {
    if (alloc_ptr <= heap_base + @sizeOf(ObjHeader)) return null;
    return @ptrFromInt(heap_base + @sizeOf(ObjHeader));
}
pub fn next_obj(cur: [*]u8) ?[*]u8 {
    const h: *ObjHeader = @ptrFromInt(@intFromPtr(cur) - @sizeOf(ObjHeader));
    const next = @intFromPtr(cur) + align16(h.size) + @sizeOf(ObjHeader);
    if (next >= alloc_ptr) return null;
    return @ptrFromInt(next);
}

fn count_pinned() usize {
    var cnt: usize = 0;
    var p = first_obj();
    while (p) |q| {
        const h: *ObjHeader = @ptrFromInt(@intFromPtr(q) - @sizeOf(ObjHeader));
        if (h.flags & 1 != 0) cnt += 1;
        p = next_obj(q);
    }
    return cnt;
}
