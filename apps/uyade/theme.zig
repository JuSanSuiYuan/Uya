pub const Color = struct { r: u8, g: u8, b: u8 };
pub const Shape = struct { radius: u8 };
pub const Spacing = struct { base4: u8, base8: u8, base12: u8, base16: u8, base24: u8 };
pub const ClockPrefs = struct { horizontal_seconds: bool, vertical_seconds: bool };
pub const Gray = struct { surface_bg: Color, container: Color, border_divider: Color, text_primary: Color, text_secondary: Color };
pub const Accent = enum { pink, sky, mint };

pub var primary: Color = .{ .r = 0xF4, .g = 0x8F, .b = 0xB1 };
pub var secondary: Color = .{ .r = 0x81, .g = 0xD4, .b = 0xFA };
pub var surface: Color = .{ .r = 0xF7, .g = 0xF7, .b = 0xF7 };
pub var on_surface: Color = .{ .r = 0x22, .g = 0x22, .b = 0x22 };
pub var pink: Color = .{ .r = 0xFF, .g = 0xD1, .b = 0xDC };
pub var sky: Color = .{ .r = 0xBD, .g = 0xE0, .b = 0xFE };
pub var mint: Color = .{ .r = 0xCD, .g = 0xEA, .b = 0xC0 };
pub var gray: Gray = .{
    .surface_bg = .{ .r = 0xF4, .g = 0xF4, .b = 0xF4 },
    .container = .{ .r = 0xEA, .g = 0xEA, .b = 0xEA },
    .border_divider = .{ .r = 0xD8, .g = 0xD8, .b = 0xD8 },
    .text_primary = .{ .r = 0x22, .g = 0x22, .b = 0x22 },
    .text_secondary = .{ .r = 0x55, .g = 0x55, .b = 0x55 },
};
pub var accent_sel: Accent = .pink;

pub var shape_button: Shape = .{ .radius = 10 };
pub var shape_window: Shape = .{ .radius = 0 };
pub var spacing: Spacing = .{ .base4 = 4, .base8 = 8, .base12 = 12, .base16 = 16, .base24 = 24 };
pub var clock_prefs: ClockPrefs = .{ .horizontal_seconds = true, .vertical_seconds = false };

pub fn load() void { _ = primary; }

pub fn setClockSeconds(horizontal: bool, vertical: bool) void {
    clock_prefs.horizontal_seconds = horizontal;
    clock_prefs.vertical_seconds = vertical;
}

pub fn setAccent(a: Accent) void { accent_sel = a; }
pub fn accentPrimary() Color {
    return switch (accent_sel) { .pink => primary, .sky => secondary, .mint => .{ .r = 0x8F, .g = 0xD1, .b = 0x9E } };
}