const std = @import("std");

pub const Layout = enum { apple, windows, hybrid };
var current: Layout = .hybrid; // 默认使用混合风格

// 添加搜索栏支持
var has_search_bar: bool = true;
pub fn set_search_bar(enabled: bool) void {
    has_search_bar = enabled;
}
pub fn has_search() bool {
    return has_search_bar;
}

pub fn apply(name: []const u8) void {
    if (name.len == 0) return;
    if (std.mem.eql(u8, name, "hybrid")) {
        current = .hybrid;
    } else if (name[0] == 'a') {
        current = .apple;
    } else {
        current = .windows;
    }
}

pub fn get() Layout {
    return current;
}

// 苹果风格左侧按钮：关闭、最小化、最大化
var left_items: [][]const u8 = &[_][]const u8{ "close", "min", "max" };
// 微软风格右侧按钮：最小化、最大化、关闭
var right_items: [][]const u8 = &[_][]const u8{ "min", "max", "close" };

pub fn set_left(alloc: std.mem.Allocator, arr: [][]const u8) void {
    left_items = alloc.dupe([]const u8, arr) catch &[_][]const u8{};
}

pub fn set_right(alloc: std.mem.Allocator, arr: [][]const u8) void {
    right_items = alloc.dupe([]const u8, arr) catch &[_][]const u8{};
}

pub fn get_left() [][]const u8 {
    // 混合模式下左侧总是显示苹果风格按钮
    return left_items;
}

pub fn get_right() [][]const u8 {
    // 根据布局决定右侧按钮显示
    switch (current) {
        .hybrid, .windows => return right_items,
        .apple => return &[_][]const u8{}, // 苹果模式下右侧不显示按钮
    }
}

// 获取布局类型描述，用于调试和显示
pub fn get_layout_name() []const u8 {
    switch (current) {
        .apple => return "Apple Style",
        .windows => return "Windows Style",
        .hybrid => return "Hybrid Style",
    }
}
