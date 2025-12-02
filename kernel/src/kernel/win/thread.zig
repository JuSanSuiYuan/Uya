const h = @import("win_handle");

pub const Thread = struct { id: h.Handle, entry: u64, sp: u64 };
var stack: [65536]u8 = undefined;

pub fn create(entry: u64) Thread {
    var ht = h.HandleTable.init();
    const hnd = ht.alloc();
    const sptr = @intFromPtr(&stack[stack.len - 16]);
    return .{ .id = hnd, .entry = entry, .sp = @as(u64, sptr) };
}