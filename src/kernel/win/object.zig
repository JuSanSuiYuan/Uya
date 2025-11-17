const h = @import("win_handle");
const atomic = @import("compat_atomic");

pub const Kind = enum { file, thread, shm };

var used: [64]bool = [_]bool{false} ** 64;
var kinds: [64]Kind = [_]Kind{.file} ** 64;
var paths: [64][256]u8 = undefined;
var lens: [64]usize = undefined;

// 侵入式双向链表用于活跃对象遍历
var active_head: i32 = -1;
var next_idx: [64]i32 = [_]i32{-1} ** 64;
var prev_idx: [64]i32 = [_]i32{-1} ** 64;

// 无锁自由链表（Treiber 栈）用于空闲槽位
var inited: bool = false;
var free_head: i32 = -1;
var next_free: [64]i32 = [_]i32{-1} ** 64;

fn ensureInit() void {
    if (inited) return;
    var i: i32 = 0;
    while (@as(usize, @intCast(i)) < used.len) : (i += 1) {
        used[@as(usize, @intCast(i))] = false;
        lens[@as(usize, @intCast(i))] = 0;
        next_free[@as(usize, @intCast(i))] = i + 1;
        next_idx[@as(usize, @intCast(i))] = -1;
        prev_idx[@as(usize, @intCast(i))] = -1;
    }
    next_free[used.len - 1] = -1;
    free_head = 0;
    active_head = -1;
    inited = true;
}

fn stack_pop() ?usize {
    while (true) {
        const cur = free_head;
        if (cur == -1) return null;
        const next = next_free[@as(usize, @intCast(cur))];
        if (atomic.casI32(&free_head, cur, next)) {
            return @as(usize, @intCast(cur));
        }
    }
}

fn stack_push(idx: usize) void {
    while (true) {
        const cur = free_head;
        next_free[idx] = cur;
        if (atomic.casI32(&free_head, cur, @as(i32, @intCast(idx)))) return;
    }
}

fn active_add(idx: usize) void {
    prev_idx[idx] = -1;
    while (true) {
        const cur = active_head;
        next_idx[idx] = cur;
        if (atomic.casI32(&active_head, cur, @as(i32, @intCast(idx)))) break;
    }
}

fn active_remove(idx: usize) void { _ = idx; }

pub fn create_file(path: []const u8) ?h.Handle {
    ensureInit();
    const slot = stack_pop() orelse return null;
    var len: usize = 0;
    while (len < path.len and len < 256) : (len += 1) paths[slot][len] = path[len];
    lens[slot] = if (path.len < 256) path.len else 256;
    kinds[slot] = .file;
    used[slot] = true;
    active_add(slot);
    return @as(h.Handle, slot + 1);
}

pub fn get_file(handle: h.Handle) ?[]const u8 {
    const idx = @as(usize, handle - 1);
    if (idx >= used.len) return null;
    if (!used[idx]) return null;
    if (kinds[idx] != .file) return null;
    return paths[idx][0..lens[idx]];
}

pub fn destroy(handle: h.Handle) bool {
    ensureInit();
    const idx = @as(usize, handle - 1);
    if (idx >= used.len) return false;
    if (!used[idx]) return false;
    used[idx] = false;
    lens[idx] = 0;
    active_remove(idx);
    stack_push(idx);
    return true;
}