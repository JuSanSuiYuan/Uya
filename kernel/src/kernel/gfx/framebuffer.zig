const st2 = @import("../arch/x86_64/stivale2.zig");

pub const FB = struct {
    pub var addr: usize = 0;
    pub var width: usize = 0;
    pub var height: usize = 0;
    pub var pitch: usize = 0;
    pub var bpp: usize = 0;
    const BLK: usize = 4096;
    const MAX_BLOCKS: usize = 4096;
    var base: usize = 0;
    var size_bytes: usize = 0;
    var group_base: [MAX_BLOCKS / 64]usize = undefined;
    var group_bitmap: [MAX_BLOCKS / 64]u64 = undefined;
    var group_count: usize = 0;

    pub fn init(s: *st2.Struct) void {
        var p = s.tags;
        while (p != 0) {
            const t: *st2.Tag = @ptrFromInt(p);
            if (t.identifier == 0x506461b2950408db) {
                const fb: *st2.StructTagFramebuffer = @as(*st2.StructTagFramebuffer, @ptrCast(t));
                addr = fb.framebuffer_addr;
                width = fb.framebuffer_width;
                height = fb.framebuffer_height;
                pitch = fb.framebuffer_pitch;
                bpp = fb.framebuffer_bpp;
                base = addr;
                size_bytes = @as(usize, pitch) * @as(usize, height);
                var i: usize = 0;
                while (i < group_base.len) : (i += 1) { group_base[i] = 0; group_bitmap[i] = 0; }
                group_count = 0;
                var off: usize = 0;
                while (off + BLK <= size_bytes and group_count < group_base.len) : (off += BLK * 64) {
                    group_base[group_count] = base + off;
                    var bm: u64 = 0;
                    var j: usize = 0;
                    const chunk = if ((off + BLK * 64) <= size_bytes) BLK * 64 else (size_bytes - off);
                    while (j < 64) : (j += 1) {
                        const boff = j * BLK;
                        if (boff < chunk) { bm |= (@as(u64, 1) << @as(u6, @intCast(j))); }
                    }
                    group_bitmap[group_count] = bm;
                    group_count += 1;
                }
                break;
            }
            p = t.next;
        }
    }

    pub fn putPixel(x: usize, y: usize, rgba: u32) void {
        if (addr == 0) return;
        if (x >= width or y >= height) return;
        const p: [*]u8 = @ptrFromInt(addr);
        const off = y * pitch + x * (bpp / 8);
        switch (bpp) {
            32 => {
                p[off + 0] = @as(u8, @intCast((rgba >> 0) & 0xFF));
                p[off + 1] = @as(u8, @intCast((rgba >> 8) & 0xFF));
                p[off + 2] = @as(u8, @intCast((rgba >> 16) & 0xFF));
                p[off + 3] = @as(u8, @intCast((rgba >> 24) & 0xFF));
            },
            24 => {
                p[off + 0] = @as(u8, @intCast((rgba >> 0) & 0xFF));
                p[off + 1] = @as(u8, @intCast((rgba >> 8) & 0xFF));
                p[off + 2] = @as(u8, @intCast((rgba >> 16) & 0xFF));
            },
            else => {},
        }
    }

    pub fn allocBytes(len: usize, align_bytes: usize) ?usize {
        if (group_count == 0 or len == 0) return null;
        var g: usize = 0;
        while (g < group_count) : (g += 1) {
            if (group_bitmap[g] == 0) continue;
            var bit: usize = 0;
            while (bit < 64) : (bit += 1) {
                if ((group_bitmap[g] & (@as(u64, 1) << @as(u6, @intCast(bit)))) == 0) continue;
                const off = bit * BLK;
                const addr0 = group_base[g] + off;
                const aligned = if (align_bytes == 0) addr0 else ((addr0 + align_bytes - 1) & ~(align_bytes - 1));
                if (aligned + len <= group_base[g] + 64 * BLK) {
                    group_bitmap[g] &= ~(@as(u64, 1) << @as(u6, @intCast(bit)));
                    return aligned - base;
                }
            }
        }
        return null;
    }

    pub fn freeBytes(off: usize, len: usize) void {
        var g: usize = 0;
        while (g < group_count) : (g += 1) {
            const gb = group_base[g] - base;
            const ge = gb + 64 * BLK;
            if (off >= gb and off < ge) {
                const bit = (off - gb) / BLK;
                group_bitmap[g] |= (@as(u64, 1) << @as(u6, @intCast(bit)));
                return;
            }
        }
        _ = len;
    }

    pub fn allocRect(w: usize, h: usize, align_bytes: usize) ?usize {
        if (w == 0 or h == 0) return null;
        const row = w * (bpp / 8);
        const total = row * h;
        return allocBytes(total, align_bytes);
    }

    pub fn freeRect(off: usize, w: usize, h: usize) void {
        if (w == 0 or h == 0) return;
        const row = w * (bpp / 8);
        const total = row * h;
        freeBytes(off, total);
    }
};