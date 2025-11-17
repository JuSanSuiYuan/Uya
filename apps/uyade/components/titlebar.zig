const theme = @import("../theme.zig");
const tabs = @import("tabs.zig");

pub const ControlSide = enum { left_apple, right_ms };
pub const TitleBar = struct {
    title: []const u8,
    tb: tabs.Tabs,
    pub fn init(t: []const u8) TitleBar { return .{ .title = t, .tb = tabs.Tabs.init() }; }
    pub fn onClick(self: *TitleBar, side: ControlSide, which: u8) void { _ = self; _ = side; _ = which; _ = theme.surface; }
};