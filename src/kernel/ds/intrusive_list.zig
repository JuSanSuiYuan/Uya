const tp = @import("gc_tagptr");
const bar = @import("gc_bar");
const haz = @import("gc_hazard");
pub const Node = struct { next: tp.TaggedPtr, val: usize, payload: [*]u8 };
pub const List = struct { head: tp.TaggedPtr };
pub fn init(l: *List) void { l.head = tp.init(); }
pub fn insert_head(l: *List, n: *Node) void { const old = tp.load(&l.head); tp.store(&n.next, old); bar.write_barrier(n.payload, @ptrFromInt(old)); tp.store(&l.head, @intFromPtr(n)); }
pub fn delete_even(l: *List) usize {
    var removed: usize = 0;
    var prev_addr: usize = 0;
    var prev_ver: usize = 0;
    var cur_addr: usize = tp.load(&l.head);
    var cur_ver: usize = l.head.ver;
    while (cur_addr != 0) {
        const cur: *Node = @ptrFromInt(cur_addr);
        haz.protect(cur.payload);
        const next_addr = tp.load(&cur.next);
        const next_ver = cur.next.ver;
        if ((cur.val % 2) == 0) {
            if (prev_addr == 0) { if (tp.try_update(&l.head, cur_addr, cur_ver, next_addr)) { removed += 1; cur_addr = next_addr; cur_ver = next_ver; continue; } else { fails += 1; } }
            else { const prev: *Node = @ptrFromInt(prev_addr); if (tp.try_update(&prev.next, cur_addr, prev_ver, next_addr)) { bar.write_barrier(prev.payload, @ptrFromInt(next_addr)); removed += 1; cur_addr = next_addr; cur_ver = next_ver; continue; } else { fails += 1; } }
        }
        haz.clear();
        prev_addr = cur_addr;
        prev_ver = cur_ver;
        cur_addr = next_addr;
        cur_ver = next_ver;
    }
    haz.clear();
    return removed;
}
var fails: usize = 0;
pub fn get_fail_count() usize { return fails; }
pub fn reset_fail_count() void { fails = 0; }
