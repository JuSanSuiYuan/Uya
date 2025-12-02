const std = @import("std");
const win = @import("../wm/window.zig");
const wm = @import("../wm/manager.zig");
const window_render = @import("../components/window_render.zig");
const taskbar = @import("../components/taskbar.zig");

pub const DesktopManager = struct {
    windows: std.ArrayList(win.Window),
    active_window: ?usize,
    wm_manager: wm.Manager,
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) DesktopManager {
        return .{
            .windows = std.ArrayList(win.Window).init(allocator),
            .active_window = null,
            .wm_manager = wm.Manager.init(),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *DesktopManager) void {
        self.windows.deinit();
    }
    
    pub fn addWindow(self: *DesktopManager, title: []const u8, width: u32, height: u32) !usize {
        const window = self.wm_manager.createWindow(title, .{ .w = width, .h = height });
        try self.windows.append(window);
        self.active_window = self.windows.items.len - 1;
        return self.windows.items.len - 1;
    }
    
    pub fn addMaximizedWindow(self: *DesktopManager, title: []const u8, screen_w: u32, screen_h: u32, bar: taskbar.Taskbar) !usize {
        const window = self.wm_manager.createMaximizedWindow(title, screen_w, screen_h, bar);
        try self.windows.append(window);
        self.active_window = self.windows.items.len - 1;
        return self.windows.items.len - 1;
    }
    
    pub fn setActiveWindow(self: *DesktopManager, index: usize) void {
        if (index < self.windows.items.len) {
            self.active_window = index;
        }
    }
    
    pub fn removeWindow(self: *DesktopManager, index: usize) void {
        if (index < self.windows.items.len) {
            _ = self.windows.orderedRemove(index);
            if (self.active_window) |active| {
                if (active >= self.windows.items.len) {
                    self.active_window = if (self.windows.items.len > 0) 0 else null;
                } else if (active == index) {
                    self.active_window = if (self.windows.items.len > 0) active else null;
                }
            }
        }
    }
    
    pub fn render(self: *DesktopManager) void {
        // 清屏
        window_render.Renderer.clearScreen();
        
        // 渲染所有窗口（简单的层叠显示）
        const o = std.io.getStdOut().writer();
        _ = o.print("UyaDE 桌面环境 - 窗口数量: {d}\n", .{self.windows.items.len});
        _ = o.print("活跃窗口: {?d}\n\n", .{self.active_window});
        
        // 渲染每个窗口
        var i: usize = 0;
        while (i < self.windows.items.len) : (i += 1) {
            const window = self.windows.items[i];
            const is_active = self.active_window == i;
            
            _ = o.print("{s}窗口 #{d}: {s} - {s}\n", .{ 
                if (is_active) "[活跃] " else "", 
                i, window.title, 
                switch (window.state) {
                    .normal => "正常",
                    .minimized => "最小化",
                    .maximized => "最大化",
                }
            });
            
            // 渲染窗口
            window_render.Renderer.renderWindow(window, 10, 10 + @intCast(u32, i * 30));
            
            // 渲染窗口边框预览
            window_render.Renderer.renderWindowBorder(window.size.w, 10); // 简化的边框预览
        }
        
        // 渲染桌面状态栏信息
        _ = o.print("==========================================\n", .{});
        _ = o.print("UyaDE 桌面环境 v1.0 - 木兰开源许可证 Mulan PSL 2.0\n", .{});
        _ = o.print("==========================================\n\n", .{});
    }
    
    pub fn startRenderLoop(self: *DesktopManager) !void {
        // 简单的渲染循环示例
        // 实际应用中可能需要与事件系统集成
        _ = o: { const o = std.io.getStdOut().writer(); break :o o; }.print("启动渲染循环...按Ctrl+C退出\n\n", .{});
        
        // 渲染一帧示例
        self.render();
        
        _ = o: { const o = std.io.getStdOut().writer(); break :o o; }.print("渲染循环演示完成\n", .{});
    }
};