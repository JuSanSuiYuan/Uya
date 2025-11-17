// no logging dependency in module

pub const Prot = enum(u32) { r, w, x };
pub const Fault = enum(u32) { access, not_present, write };
pub const ErrorCode = enum(u32) { ok, invalid_align, invalid_len, denied };

fn isAligned(p: usize) bool { return (p & 0xFFF) == 0; }

const MapEntry = struct { va: usize, pa: usize, len: usize, prot: Prot };
var map_table: [128]MapEntry = undefined;
var map_count: usize = 0;
const cap_epoch = @import("cap_epoch");
const radix = @import("util_radix_tree");
var nodes_a: [8]radix.Node = undefined;
var nodes_b: [8]radix.Node = undefined;
var which_buf: u8 = 0;
var root: radix.Root = .{ .ptr = &nodes_a[0], .ver = 0 };

fn rebuild_index() void {
    var buf: *[8]radix.Node = if (which_buf == 0) &nodes_b else &nodes_a;
    var bi: usize = 0;
    var ti: usize = 0;
    while (bi < buf.len) : (bi += 1) {
        var j: usize = 0;
        while (j < 16) : (j += 1) {
            buf.*[bi].keys[j] = 0;
            buf.*[bi].vals[j] = 0;
        }
        buf.*[bi].next = null;
    }
    bi = 0;
    while (ti < map_count) : (ti += 1) {
        var slot: usize = 0;
        while (slot < 16 and buf.*[bi].keys[slot] != 0) : (slot += 1) {}
        if (slot == 16) {
            if (bi + 1 >= buf.len) break;
            buf.*[bi].next = &buf.*[bi + 1];
            bi += 1;
            slot = 0;
        }
        buf.*[bi].keys[slot] = @as(u64, @intCast(map_table[ti].va));
        buf.*[bi].vals[slot] = ti;
    }
    root = radix.publish(root, &buf.*[0]);
    which_buf = if (which_buf == 0) 1 else 0;
}

pub fn mm_map(proc: *anyopaque, va: usize, pa: usize, len: usize, prot: Prot) ErrorCode {
    _ = proc;
    if (!isAligned(va) or !isAligned(pa)) return .invalid_align;
    if (len == 0 or (len & 0xFFF) != 0) return .invalid_len;
    if (map_count >= map_table.len) return .denied;
    map_table[map_count] = .{ .va = va, .pa = pa, .len = len, .prot = prot };
    map_count += 1;
    rebuild_index();
    return .ok;
}

pub fn mm_unmap(proc: *anyopaque, va: usize, len: usize) ErrorCode {
    _ = proc;
    if (!isAligned(va)) return .invalid_align;
    if (len == 0 or (len & 0xFFF) != 0) return .invalid_len;
    var i: usize = 0;
    while (i < map_count) : (i += 1) {
        if (map_table[i].va == va and map_table[i].len == len) {
            var j: usize = i;
            while (j + 1 < map_count) : (j += 1) map_table[j] = map_table[j + 1];
            map_count -= 1;
            rebuild_index();
            return .ok;
        }
    }
    return .denied;
}

pub fn mm_protect(proc: *anyopaque, va: usize, len: usize, prot: Prot) ErrorCode {
    _ = proc;
    if (!isAligned(va)) return .invalid_align;
    if (len == 0 or (len & 0xFFF) != 0) return .invalid_len;
    var i: usize = 0;
    while (i < map_count) : (i += 1) {
        if (map_table[i].va == va and map_table[i].len == len) {
            map_table[i].prot = prot;
            rebuild_index();
            return .ok;
        }
    }
    return .denied;
}

pub fn mm_fault(proc: *anyopaque, va: usize, reason: Fault) ErrorCode {
    _ = proc;
    const tok = cap_epoch.enter();
    defer cap_epoch.exit(tok);
    const idx_opt = radix.lookup(root.ptr, @as(u64, @intCast(va)));
    if (idx_opt) |idx| {
        const me = map_table[idx];
        if (va >= me.va and va < me.va + me.len) {
            return switch (reason) {
                .access => .ok,
                .write => if (me.prot == .w) .ok else .denied,
                .not_present => .denied,
            };
        }
    }
    return .not_present;
}