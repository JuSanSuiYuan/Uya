pub const Layout = enum { apple, windows };
var current: Layout = .windows;
pub fn apply(name: []const u8) void {
    if (name.len == 0) return;
    if (name[0] == 'a') { current = .apple; }
    else { current = .windows; }
}
pub fn get() Layout { return current; }
var left_items: [][]const u8 = &[_][]const u8{ "close", "min", "max" };
var right_items: [][]const u8 = &[_][]const u8{ "max", "min", "close" };
pub fn set_left(alloc: std.mem.Allocator, arr: [][]const u8) void {
    left_items = alloc.dupe([]const u8, arr) catch &[_][]const u8{};
}
pub fn set_right(alloc: std.mem.Allocator, arr: [][]const u8) void {
    right_items = alloc.dupe([]const u8, arr) catch &[_][]const u8{};
}
pub fn get_left() [][]const u8 { return left_items; }
pub fn get_right() [][]const u8 { return right_items; }
