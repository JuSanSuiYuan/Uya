// Material3风格的莫兰迪色系配色方案
const std = @import("std");

// 主色调 - 深蓝色
pub const Primary = struct {
    // 主色
    pub const main: u32 = 0x1976D2; // 深蓝色
    pub const light: u32 = 0x42A5F5;
    pub const dark: u32 = 0x0D47A1;
    // 文字颜色
    pub const on_main: u32 = 0xFFFFFF;
    pub const on_light: u32 = 0x000000;
    pub const on_dark: u32 = 0xFFFFFF;
};

// 辅助色1 - 粉红色（莫兰迪风格）
pub const Secondary = struct {
    // 主色
    pub const main: u32 = 0xE91E63; // 粉红色
    pub const light: u32 = 0xF06292;
    pub const dark: u32 = 0xC2185B;
    // 文字颜色
    pub const on_main: u32 = 0xFFFFFF;
    pub const on_light: u32 = 0x000000;
    pub const on_dark: u32 = 0xFFFFFF;
};

// 辅助色2 - 天蓝色（莫兰迪风格）
pub const Tertiary = struct {
    // 主色
    pub const main: u32 = 0x00BCD4; // 天蓝色
    pub const light: u32 = 0x4DD0E1;
    pub const dark: u32 = 0x0097A7;
    // 文字颜色
    pub const on_main: u32 = 0x000000;
    pub const on_light: u32 = 0x000000;
    pub const on_dark: u32 = 0xFFFFFF;
};

// 辅助色3 - 淡绿色（莫兰迪风格）
pub const Accent = struct {
    // 主色
    pub const main: u32 = 0x4CAF50; // 淡绿色
    pub const light: u32 = 0x81C784;
    pub const dark: u32 = 0x388E3C;
    // 文字颜色
    pub const on_main: u32 = 0x000000;
    pub const on_light: u32 = 0x000000;
    pub const on_dark: u32 = 0xFFFFFF;
};

// 中性色
pub const Surface = struct {
    pub const background: u32 = 0xFFFFFF;
    pub const surface: u32 = 0xF5F5F5;
    pub const card: u32 = 0xFFFFFF;
    pub const divider: u32 = 0xE0E0E0;
    pub const outline: u32 = 0xBDBDBD;
    // 文字颜色
    pub const on_background: u32 = 0x212121;
    pub const on_surface: u32 = 0x212121;
    pub const on_card: u32 = 0x212121;
    pub const on_divider: u32 = 0x9E9E9E;
};

// 按钮颜色映射
pub fn getButtonColor(name: []const u8) u32 {
    if (std.mem.eql(u8, name, "close")) {
        return Secondary.main; // 关闭按钮使用粉红色
    } else if (std.mem.eql(u8, name, "min")) {
        return Tertiary.main; // 最小化按钮使用天蓝色
    } else if (std.mem.eql(u8, name, "max")) {
        return Accent.main; // 最大化按钮使用淡绿色
    }
    return Surface.outline; // 默认颜色
}

// 将ARGB颜色转换为CSS颜色字符串
pub fn toHexColor(color: u32) []const u8 {
    return std.fmt.allocPrint(std.heap.page_allocator, "#{X:06}", .{color}) catch return "#000000";
}