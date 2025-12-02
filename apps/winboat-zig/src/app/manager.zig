// WinBoat-Zig 应用管理器
// 许可证: MulanPSL-2.0

const std = @import("std");
const types = @import("../config/types.zig");

pub const AppManager = struct {
    allocator: std.mem.Allocator,
    apps: std.ArrayList(types.AppInfo),
    usage_file_path: []const u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, usage_file_path: []const u8) !Self {
        return Self{
            .allocator = allocator,
            .apps = std.ArrayList(types.AppInfo).init(allocator),
            .usage_file_path = try allocator.dupe(u8, usage_file_path),
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.apps.items) |app| {
            self.allocator.free(app.name);
            self.allocator.free(app.path);
            self.allocator.free(app.args);
            self.allocator.free(app.icon);
        }
        self.apps.deinit();
        self.allocator.free(self.usage_file_path);
    }

    /// 从 Guest 同步应用列表
    pub fn syncApps(self: *Self) !void {
        std.debug.print("同步应用列表\n", .{});
        
        // TODO: 从 Guest Server 获取应用列表
        // 添加预设应用
        try self.addPresetApps();
    }

    fn addPresetApps(self: *Self) !void {
        // Windows Desktop
        try self.apps.append(.{
            .name = try self.allocator.dupe(u8, "⚙️ Windows Desktop"),
            .path = try self.allocator.dupe(u8, "WINDOWS_DESKTOP"),
            .args = try self.allocator.dupe(u8, ""),
            .icon = try self.allocator.dupe(u8, ""),
            .source = .internal,
            .usage = 0,
        });

        // Windows Explorer
        try self.apps.append(.{
            .name = try self.allocator.dupe(u8, "⚙️ Windows Explorer"),
            .path = try self.allocator.dupe(u8, "%windir%\\explorer.exe"),
            .args = try self.allocator.dupe(u8, ""),
            .icon = try self.allocator.dupe(u8, ""),
            .source = .internal,
            .usage = 0,
        });
    }

    /// 添加自定义应用
    pub fn addCustomApp(self: *Self, name: []const u8, path: []const u8, args: []const u8, icon: []const u8) !void {
        try self.apps.append(.{
            .name = try self.allocator.dupe(u8, name),
            .path = try self.allocator.dupe(u8, path),
            .args = try self.allocator.dupe(u8, args),
            .icon = try self.allocator.dupe(u8, icon),
            .source = .custom,
            .usage = 0,
        });
    }

    /// 移除自定义应用
    pub fn removeCustomApp(self: *Self, name: []const u8) !void {
        var i: usize = 0;
        while (i < self.apps.items.len) {
            if (std.mem.eql(u8, self.apps.items[i].name, name)) {
                const app = self.apps.orderedRemove(i);
                self.allocator.free(app.name);
                self.allocator.free(app.path);
                self.allocator.free(app.args);
                self.allocator.free(app.icon);
                return;
            }
            i += 1;
        }
        return error.AppNotFound;
    }

    /// 增加应用使用次数
    pub fn incrementUsage(self: *Self, name: []const u8) !void {
        for (self.apps.items) |*app| {
            if (std.mem.eql(u8, app.name, name)) {
                app.usage += 1;
                try self.saveUsage();
                return;
            }
        }
    }

    /// 保存使用统计
    fn saveUsage(self: *Self) !void {
        const file = try std.fs.cwd().createFile(self.usage_file_path, .{});
        defer file.close();

        // TODO: 实现 JSON 序列化
        const json = "{}"; // 占位符
        try file.writeAll(json);
    }

    /// 获取应用列表
    pub fn getApps(self: *Self) []const types.AppInfo {
        return self.apps.items;
    }
};
