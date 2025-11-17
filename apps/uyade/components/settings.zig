const theme = @import("../theme.zig");
const taskbar = @import("taskbar.zig");

pub const Settings = struct {
    accent: theme.Accent,
    horiz_seconds: bool,
    vert_seconds: bool,
    bar_orientation: taskbar.Orientation,
    pub fn init() Settings { return .{ .accent = .pink, .horiz_seconds = true, .vert_seconds = false, .bar_orientation = .bottom }; }
    pub fn apply(self: *Settings) void {
        theme.setAccent(self.accent);
        theme.setClockSeconds(self.horiz_seconds, self.vert_seconds);
    }
    pub fn getBarOrientation(self: *const Settings) taskbar.Orientation { return self.bar_orientation; }
};