pub const Tabs = struct {
    count: usize,
    pub fn init() Tabs { return .{ .count = 0 }; }
    pub fn add(self: *Tabs, title: []const u8) void { _ = self; _ = title; }
    pub fn close(self: *Tabs, idx: usize) void { _ = self; _ = idx; }
};