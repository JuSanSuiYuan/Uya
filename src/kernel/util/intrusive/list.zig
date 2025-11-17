const std = @import("std");

pub const Node = struct {
    next: ?*Node = null,
    prev: ?*Node = null,
    tombstone: bool = false,
};

pub const List = struct {
    head: ?*Node = null,
    pub fn push(self: *List, n: *Node) void {
        n.prev = null;
        while (true) {
            const cur = self.head;
            n.next = cur;
            if (@atomicRmw(?*Node, &self.head, .Xchg, n, .monotonic) == cur) break;
        }
    }
};