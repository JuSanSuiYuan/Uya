const theme = @import("../theme.zig");
const std = @import("std");

pub const Tray = struct {
    count: u8,
    names: std.ArrayListUnmanaged([]u8),
    pub fn init() Tray { return .{ .count = 0, .names = .{} }; }
    pub fn add(self: *Tray) void { if (self.count < 255) self.count += 1; }
    pub fn color(self: *Tray) theme.Color { _ = self; return theme.accentPrimary(); }
    pub fn clear(self: *Tray, alloc: std.mem.Allocator) void {
        var i: usize = 0;
        while (i < self.names.items.len) : (i += 1) alloc.free(self.names.items[i]);
        self.names.clearRetainingCapacity();
        self.count = 0;
    }
    pub fn deinit(self: *Tray, alloc: std.mem.Allocator) void {
        self.clear(alloc);
        self.names.deinit(alloc);
    }
    pub fn equalsOrder(self: *const Tray, arr: [][]const u8) bool {
        if (self.names.items.len != arr.len) return false;
        var i: usize = 0;
        while (i < arr.len) : (i += 1) {
            if (!std.mem.eql(u8, self.names.items[i], arr[i])) return false;
        }
        return true;
    }
    pub fn replaceIcons(self: *Tray, alloc: std.mem.Allocator, arr: [][]const u8) !void {
        self.clear(alloc);
        try self.names.ensureTotalCapacity(alloc, arr.len);
        var i: usize = 0;
        while (i < arr.len) : (i += 1) {
            const src = arr[i];
            const dup = try alloc.alloc(u8, src.len);
            std.mem.copyForwards(u8, dup, src);
            try self.names.append(alloc, dup);
        }
        self.count = @intCast(@min(arr.len, 255));
    }
};
pub fn create() Tray { return Tray.init(); }