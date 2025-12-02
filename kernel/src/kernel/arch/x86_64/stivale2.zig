const std = @import("std");
// serial disabled in current build; logging will be no-op
pub const PhysEntry = MemmapEntry;

pub const Tag = extern struct {
    identifier: u64,
    next: u64,
};

pub const Struct = extern struct {
    bootloader_brand: *const u8,
    bootloader_version: *const u8,
    tags: u64,
};

pub const MemmapEntry = extern struct {
    base: u64,
    length: u64,
    type: u32,
    unused: u32,
};

pub const StructTagMemmap = extern struct {
    tag: Tag,
    entries: u64,
    entries_len: u64,
};

pub const StructTagFramebuffer = extern struct {
    tag: Tag,
    framebuffer_addr: u64,
    framebuffer_width: u16,
    framebuffer_height: u16,
    framebuffer_pitch: u16,
    framebuffer_bpp: u16,
    memory_model: u8,
    red_mask_size: u8,
    red_mask_shift: u8,
    green_mask_size: u8,
    green_mask_shift: u8,
    blue_mask_size: u8,
    blue_mask_shift: u8,
};

pub const Header = extern struct {
    entry_point: u64,
    stack: u64,
    flags: u64,
    tags: u64,
};

pub const HDR_TAG_FB: u64 = 0x3ecc1bc43d0f7971;
pub const HDR_TAG_MEMMAP: u64 = 0x2187f79e8612de07;
pub const TAG_SMP: u64 = 0x34d1d96339684f5e;
pub const TAG_RSDP: u64 = 0x9e1786930a375e78;

var hdr_tag_fb: Tag = .{ .identifier = HDR_TAG_FB, .next = 0 };
var hdr_tag_mem: Tag = .{ .identifier = HDR_TAG_MEMMAP, .next = 0 };
var header: Header linksection(".stivale2hdr") = .{
    .entry_point = 0,
    .stack = 0,
    .flags = 0,
    .tags = 0,
};

pub fn initHeaderChain() void {
    hdr_tag_mem.next = @intFromPtr(&hdr_tag_fb);
    header.tags = @intFromPtr(&hdr_tag_mem);
}

fn findTag(s: *Struct, id: u64) ?*Tag {
    var p = s.tags;
    while (p != 0) {
        const t: *Tag = @ptrFromInt(p);
        if (t.identifier == id) return t;
        p = t.next;
    }
    return null;
}

pub fn printBootStats(s: *Struct) void {
    _ = s.bootloader_brand;
    if (findTag(s, 0x2187f79e8612de07)) |t| {
        const mm: *StructTagMemmap = @as(*StructTagMemmap, @ptrCast(t));
        const len: usize = @as(usize, @intCast(mm.entries_len));
        _ = len;
    }
    if (findTag(s, 0x506461b2950408db)) |t| {
        const fb: *StructTagFramebuffer = @as(*StructTagFramebuffer, @ptrCast(t));
        const w: usize = fb.framebuffer_width;
        const h: usize = fb.framebuffer_height;
        _ = w; _ = h;
    }
}

pub fn getMemmap(s: *Struct) ?struct { ptr: [*]MemmapEntry, len: usize } {
    var p = s.tags;
    while (p != 0) {
        const t: *Tag = @ptrFromInt(p);
        if (t.identifier == 0x2187f79e8612de07) {
            const mm: *StructTagMemmap = @as(*StructTagMemmap, @ptrCast(t));
            const ptr: [*]MemmapEntry = @ptrFromInt(mm.entries);
            const len: usize = @as(usize, @intCast(mm.entries_len));
            return .{ .ptr = ptr, .len = len };
        }
        p = t.next;
    }
    return null;
}

pub const StructTagSmp = extern struct {
    tag: Tag,
    flags: u64,
    bsp_lapic_id: u32,
    unused: u32,
    cpu_count: u64,
    cpus: u64,
};

pub fn getSmpCoreCount(s: *Struct) ?u32 {
    var p = s.tags;
    while (p != 0) {
        const t: *Tag = @ptrFromInt(p);
        if (t.identifier == TAG_SMP) {
            const smp: *StructTagSmp = @as(*StructTagSmp, @ptrCast(t));
            return @as(u32, @intCast(smp.cpu_count));
        }
        p = t.next;
    }
    return null;
}

pub const StructTagRsdp = extern struct { tag: Tag, rsdp: u64 };
pub fn getRsdpPtr(s: *Struct) ?usize {
    var p = s.tags;
    while (p != 0) {
        const t: *Tag = @ptrFromInt(p);
        if (t.identifier == TAG_RSDP) {
            const r: *StructTagRsdp = @as(*StructTagRsdp, @ptrCast(t));
            return @as(usize, @intCast(r.rsdp));
        }
        p = t.next;
    }
    return null;
}
