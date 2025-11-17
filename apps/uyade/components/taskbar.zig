const theme = @import("../theme.zig");
const clock = @import("clock.zig");

pub const Orientation = enum { top, bottom, left, right };

pub const Taskbar = struct {
    x: i32,
    y: i32,
    width: u32,
    height: u16,
    left_margin: u16,
    right_margin: u16,
    top_margin: u16,
    bottom_margin: u16,
    orientation: Orientation,
    clk: clock.Clock,
    pub fn reorient(self: *Taskbar, screen_w: u32, screen_h: u32, ori: Orientation) void {
        self.* = Taskbar.init(screen_w, screen_h, ori);
    }
    pub fn inferOrientationFromDrag(drop_x: i32, drop_y: i32, screen_w: u32, screen_h: u32) Orientation {
        const dist_top: u32 = @as(u32, @intCast(@abs(drop_y)));
        const dist_bottom: u32 = @as(u32, @intCast(@abs(@as(i32, @intCast(screen_h)) - drop_y)));
        const dist_left: u32 = @as(u32, @intCast(@abs(drop_x)));
        const dist_right: u32 = @as(u32, @intCast(@abs(@as(i32, @intCast(screen_w)) - drop_x)));
        var best_dist: u32 = dist_top;
        var best_ori: Orientation = .top;
        if (dist_bottom < best_dist) { best_dist = dist_bottom; best_ori = .bottom; }
        if (dist_left < best_dist) { best_dist = dist_left; best_ori = .left; }
        if (dist_right < best_dist) { best_dist = dist_right; best_ori = .right; }
        return best_ori;
    }
    pub fn dockFromDrag(screen_w: u32, screen_h: u32, drop_x: i32, drop_y: i32) Taskbar {
        const ori = inferOrientationFromDrag(drop_x, drop_y, screen_w, screen_h);
        return Taskbar.init(screen_w, screen_h, ori);
    }
    pub fn workArea(self: *const Taskbar, screen_w: u32, screen_h: u32) struct { x: i32, y: i32, w: u32, h: u32 } {
        return switch (self.orientation) {
            .bottom => .{ .x = 0, .y = 0, .w = screen_w, .h = screen_h - @as(u32, self.height) },
            .top => .{ .x = 0, .y = @as(i32, self.height), .w = screen_w, .h = screen_h - @as(u32, self.height) },
            .left => .{ .x = @as(i32, @intCast(self.width)), .y = 0, .w = screen_w - self.width, .h = screen_h },
            .right => .{ .x = 0, .y = 0, .w = screen_w - self.width, .h = screen_h },
        };
    }
    pub fn init(screen_w: u32, screen_h: u32, ori: Orientation) Taskbar {
        const base4: u16 = @as(u16, theme.spacing.base4);
        const base8: u16 = @as(u16, theme.spacing.base8);
        const base12: u16 = @as(u16, theme.spacing.base12);
        const reserved_start_w: u16 = 16; // 与 StartButton.vis_w 对齐
        const reserved_start_h: u16 = 32; // 与 StartButton.vis_h 对齐
        switch (ori) {
            .bottom => {
                const h: u16 = 48;
                const lm: u16 = base8 + reserved_start_w + base4; // 为屏幕左下角开始按钮预留空间
                const rm: u16 = base12;
                const y: i32 = @as(i32, @intCast(screen_h - h));
                const x: i32 = @as(i32, lm);
                const w: u32 = screen_w - @as(u32, lm + rm);
                return .{ .x = x, .y = y, .width = w, .height = h, .left_margin = lm, .right_margin = rm, .top_margin = 0, .bottom_margin = 0, .orientation = .bottom, .clk = clock.Clock.init(.horizontal, theme.clock_prefs.horizontal_seconds) };
            },
            .top => {
                const h: u16 = 48;
                const lm: u16 = base8 + reserved_start_w + base4; // 保持左右留空一致
                const rm: u16 = base12;
                const y: i32 = 0;
                const x: i32 = @as(i32, lm);
                const w: u32 = screen_w - @as(u32, lm + rm);
                return .{ .x = x, .y = y, .width = w, .height = h, .left_margin = lm, .right_margin = rm, .top_margin = 0, .bottom_margin = 0, .orientation = .top, .clk = clock.Clock.init(.horizontal, theme.clock_prefs.horizontal_seconds) };
            },
            .left => {
                const w_fixed: u16 = 48;
                const tm: u16 = base12;
                const bm: u16 = base8 + reserved_start_h + base4; // 为屏幕左下角开始按钮预留竖向空间
                const x: i32 = 0;
                const y: i32 = @as(i32, tm);
                const h: u16 = @as(u16, @intCast(screen_h - @as(u32, tm + bm)));
                return .{ .x = x, .y = y, .width = w_fixed, .height = h, .left_margin = 0, .right_margin = 0, .top_margin = tm, .bottom_margin = bm, .orientation = .left, .clk = clock.Clock.init(.vertical_two_per_line, theme.clock_prefs.vertical_seconds) };
            },
            .right => {
                const w_fixed: u16 = 48;
                const tm: u16 = base12;
                const bm: u16 = base12; // 竖向任务栏上下均留少量空间
                const x: i32 = @as(i32, @intCast(screen_w - w_fixed));
                const y: i32 = @as(i32, tm);
                const h: u16 = @as(u16, @intCast(screen_h - @as(u32, tm + bm)));
                return .{ .x = x, .y = y, .width = w_fixed, .height = h, .left_margin = 0, .right_margin = 0, .top_margin = tm, .bottom_margin = bm, .orientation = .right, .clk = clock.Clock.init(.vertical_two_per_line, theme.clock_prefs.vertical_seconds) };
            },
        }
    }
    pub fn color() theme.Color { return theme.gray.container; }
};