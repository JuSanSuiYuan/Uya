const tb = @import("../components/titlebar.zig");

pub const Size = struct { w: u32, h: u32 };
pub const State = enum { normal, minimized, maximized };
pub const Window = struct {
    title: []const u8,
    size: Size,
    state: State,
    bar: tb.TitleBar,
    pub fn init(title: []const u8, size: Size) Window { return .{ .title = title, .size = size, .state = .normal, .bar = tb.TitleBar.init(title) }; }
};