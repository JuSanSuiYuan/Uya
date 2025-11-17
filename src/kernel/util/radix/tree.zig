const std = @import("std");

pub const Ver = u32;

pub const Node = struct {
    // immutable after publish
    // bitmap/indexed children; simplified as fixed fanout for now
    keys: [16]u64,
    vals: [16]usize,
    next: ?*const Node,
};

pub const Root = struct { ptr: *const Node, ver: Ver };

pub const Tree = struct {
    root: Root,
    pub fn init(n: *const Node) Tree { return .{ .root = .{ .ptr = n, .ver = 0 } }; }
};

pub fn lookup(n: *const Node, key: u64) ?usize {
    var i: usize = 0;
    while (i < n.keys.len) : (i += 1) if (n.keys[i] == key) return n.vals[i];
    if (n.next) |nn| return lookup(nn, key) else return null;
}

pub fn publish(old: Root, new_ptr: *const Node) Root {
    return .{ .ptr = new_ptr, .ver = old.ver +% 1 };
}

pub fn build_single(alloc: std.mem.Allocator, key: u64, val: usize) !*Node {
    var n = try alloc.create(Node);
    var i: usize = 0;
    while (i < 16) : (i += 1) { n.keys[i] = 0; n.vals[i] = 0; }
    n.keys[0] = key;
    n.vals[0] = val;
    n.next = null;
    return n;
}