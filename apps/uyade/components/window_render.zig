const std = @import("std");
const win = @import("../wm/window.zig");
const theme = @import("../theme.zig");
const tb_render = @import("titlebar_render.zig");

pub const Renderer = struct {
    pub fn renderWindow(window: win.Window, x: u32, y: u32) void {
        const o = std.io.getStdOut().writer();
        
        // 渲染窗口边框和背景
        _ = o.print("渲染窗口: '{s}' [{d}x{d}] @ ({d},{d})", .{ 
            window.title, window.size.w, window.size.h, x, y 
        });
        
        // 渲染窗口状态
        _ = o.print(" - 状态: ", .{});
        switch (window.state) {
            .normal => _ = o.print("正常", .{}),
            .minimized => _ = o.print("最小化", .{}),
            .maximized => _ = o.print("最大化", .{}),
        }
        _ = o.print("\n", .{});
        
        // 渲染窗口主题
        _ = o.print("窗口主题: 主色 #{X:02X:02X:02X}, 背景色 #{X:02X:02X:02X}\n", .{ 
            theme.primary.r, theme.primary.g, theme.primary.b,
            theme.surface.r, theme.surface.g, theme.surface.b
        });
        
        // 渲染标题栏
        _ = o.print("窗口标题栏: ", .{});
        tb_render.render_ascii(@intCast(usize, window.size.w), 24);
        
        // 渲染窗口内容区域
        _ = o.print("窗口内容区域: {d}x{d}\n\n", .{ 
            window.size.w, window.size.h - 24 // 假设标题栏高度为24
        });
    }
    
    pub fn renderWindowBorder(width: u32, height: u32) void {
        const o = std.io.getStdOut().writer();
        const w = @intCast(usize, width);
        const h = @intCast(usize, height);
        
        // 绘制上边框
        _ = o.print("{c}", .{'┌'});
        var i: usize = 0;
        while (i < w - 2) : (i += 1) {
            _ = o.print("{c}", .{'─'});
        }
        _ = o.print("{c}\n", .{'┐'});
        
        // 绘制中间部分
        i = 0;
        while (i < h - 2) : (i += 1) {
            _ = o.print("{c}", .{'│'});
            var j: usize = 0;
            while (j < w - 2) : (j += 1) {
                _ = o.print(" ", .{});
            }
            _ = o.print("{c}\n", .{'│'});
        }
        
        // 绘制下边框
        _ = o.print("{c}", .{'└'});
        i = 0;
        while (i < w - 2) : (i += 1) {
            _ = o.print("{c}", .{'─'});
        }
        _ = o.print("{c}\n\n", .{'┘'});
    }
    
    pub fn clearScreen() void {
        const o = std.io.getStdOut().writer();
        // 使用ANSI转义序列清屏
        _ = o.print("\x1B[2J\x1B[H", .{});
    }
};