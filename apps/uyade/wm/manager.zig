const win = @import("window.zig");
const taskbar = @import("../components/taskbar.zig");

pub const Manager = struct {
    pub fn init() Manager { return .{}; }
    pub fn createWindow(self: *Manager, title: []const u8, size: win.Size) win.Window { _ = self; return win.Window.init(title, size); }
    pub fn createMaximizedWindow(self: *Manager, title: []const u8, screen_w: u32, screen_h: u32, bar: taskbar.Taskbar) win.Window {
        _ = self;
        const work = bar.workArea(screen_w, screen_h);
        return win.Window.init(title, .{ .w = work.w, .h = work.h });
    }
};