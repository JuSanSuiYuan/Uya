const theme = @import("../theme.zig");
const taskbar = @import("taskbar.zig");

pub const StartButton = struct {
    vis_w: u16,
    vis_h: u16,
    hit_w: u16,
    hit_h: u16,
    margin_x: u16,
    margin_y: u16,
    x: i32,
    y: i32,
    pub fn init(screen_w: u32, screen_h: u32) StartButton {
        _ = screen_w;
        const vw: u16 = 16;
        const vh: u16 = 32;
        const hw: u16 = 36;
        const hh: u16 = 40;
        const mx: u16 = 8;
        const my: u16 = 8;
        const px: i32 = @as(i32, mx);
        const py: i32 = @as(i32, @intCast(@as(u32, screen_h) - @as(u32, vh) - @as(u32, my)));
        return .{ .vis_w = vw, .vis_h = vh, .hit_w = hw, .hit_h = hh, .margin_x = mx, .margin_y = my, .x = px, .y = py };
    }
    pub fn initForBar(bar: taskbar.Taskbar) StartButton {
        const vw: u16 = 16;
        const vh: u16 = 32;
        const hw: u16 = 36;
        const hh: u16 = 40;
        const mx: u16 = 8;
        const my: u16 = 8;
        const left_x: i32 = bar.x + @as(i32, mx);
        const right_x: i32 = bar.x + @as(i32, @intCast(bar.width)) - @as(i32, mx) - @as(i32, vw);
        const top_y: i32 = bar.y + @as(i32, my);
        const bottom_y: i32 = bar.y + @as(i32, @intCast(bar.height)) - @as(i32, my) - @as(i32, vh);
        const px: i32 = switch (bar.orientation) { .bottom, .top => left_x, .left => left_x, .right => right_x };
        const py: i32 = switch (bar.orientation) { .bottom => bottom_y, .top => top_y, .left => top_y, .right => top_y };
        return .{ .vis_w = vw, .vis_h = vh, .hit_w = hw, .hit_h = hh, .margin_x = mx, .margin_y = my, .x = px, .y = py };
    }
    pub fn color() theme.Color { return theme.accentPrimary(); }
};