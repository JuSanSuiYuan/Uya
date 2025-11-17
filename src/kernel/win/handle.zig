pub const Handle = u64;

pub const HandleTable = struct {
    next: Handle,
    pub fn init() HandleTable { return .{ .next = 1 }; }
    pub fn alloc(self: *HandleTable) Handle { const h = self.next; self.next += 1; return h; }
};