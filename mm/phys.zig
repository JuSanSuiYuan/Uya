const std = @import("std");

pub const Entry = extern struct { base: u64, length: u64, type: u32, unused: u32 };

const PAGE_SIZE: usize = 4096;
const GROUP_SIZE: usize = 64;
const MAX_GROUPS: usize = 256;

var group_base: [MAX_GROUPS]u64 = undefined;
var group_bitmap: [MAX_GROUPS]u64 = undefined;
var group_count: usize = 0;

fn setBit(bm: *u64, idx: usize) void { bm.* |= (@as(u64, 1) << @as(u6, @intCast(idx))); }
fn clearBit(bm: *u64, idx: usize) void { bm.* &= ~(@as(u64, 1) << @as(u6, @intCast(idx))); }
fn testBit(bm: u64, idx: usize) bool { return (bm & (@as(u64, 1) << @as(u6, @intCast(idx)))) != 0; }

pub fn init(entries: [*]Entry, len: usize) void {
    group_count = 0;
    var i: usize = 0;
    while (i < MAX_GROUPS) : (i += 1) { group_base[i] = 0; group_bitmap[i] = 0; }
    var k: usize = 0;
    while (k < len and group_count < MAX_GROUPS) : (k += 1) {
        const base = entries[k].base;
        const length = entries[k].length;
        var p: u64 = base;
        var rem: u64 = length;
        const group_bytes: u64 = @as(u64, PAGE_SIZE * GROUP_SIZE);
        while (rem >= @as(u64, PAGE_SIZE) and group_count < MAX_GROUPS) {
            group_base[group_count] = p;
            var bm: u64 = 0;
            var j: usize = 0;
            const chunk: u64 = if (rem > group_bytes) group_bytes else rem;
            while (j < GROUP_SIZE) : (j += 1) {
                const offs: u64 = @as(u64, j * PAGE_SIZE);
                if (offs < chunk) { bm |= (@as(u64, 1) << @as(u6, @intCast(j))); }
            }
            group_bitmap[group_count] = bm;
            group_count += 1;
            p += group_bytes;
            rem -= chunk;
        }
    }
}

pub fn alloc() ?u64 {
    var g: usize = 0;
    while (g < group_count) : (g += 1) {
        if (group_bitmap[g] == 0) continue;
        var bit: usize = 0;
        while (bit < GROUP_SIZE) : (bit += 1) {
            if (testBit(group_bitmap[g], bit)) {
                clearBit(&group_bitmap[g], bit);
                return group_base[g] + @as(u64, bit * PAGE_SIZE);
            }
        }
    }
    return null;
}

pub fn free(p: u64) void {
    var g: usize = 0;
    while (g < group_count) : (g += 1) {
        const gb = group_base[g];
        const ge = gb + @as(u64, GROUP_SIZE * PAGE_SIZE);
        if (p >= gb and p < ge) {
            const off: usize = @as(usize, @intCast(p - gb)) / PAGE_SIZE;
            setBit(&group_bitmap[g], off);
            return;
        }
    }
}
