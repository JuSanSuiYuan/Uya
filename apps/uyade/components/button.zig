const theme = @import("../theme.zig");

pub const Button = struct {
    text: []const u8,
    pub fn draw(self: *Button) void { _ = self; _ = theme.shape_button; }
};