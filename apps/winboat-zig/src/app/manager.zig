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
        // 简化实现，使用空数组
        return Self{
            .allocator = allocator,
            .apps = std.ArrayList(types.AppInfo){}, // 空初始化
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
        self.apps.deinit(self.allocator);
        self.allocator.free(self.usage_file_path);
    }

    /// 从 Guest 同步应用列表
    pub fn syncApps(self: *Self) !void {
        std.debug.print("同步应用列表\n", .{});
        
        // 清空现有应用列表
        for (self.apps.items) |app| {
            self.allocator.free(app.name);
            self.allocator.free(app.path);
            self.allocator.free(app.args);
            self.allocator.free(app.icon);
        }
        self.apps.clearAndFree();
        
        // 首先添加默认应用
        try self.addPresetApps();
        
        // 尝试从 Guest Server 获取应用列表
        var server_apps: ?[]types.AppInfo = null;
        
        // 尝试连接到 Guest Server 获取应用列表
        server_apps = self.fetchAppsFromGuestServer() catch |err| {
            std.debug.print("从 Guest Server 获取应用列表失败: {s}, 使用默认应用\n", .{@errorName(err)});
            null
        };
        
        // 如果成功获取到应用列表，添加到现有列表
        if (server_apps) |apps| {
            for (apps) |app| {
                // 避免重复添加
                var exists = false;
                for (self.apps.items) |existing_app| {
                    if (std.mem.eql(u8, app.name, existing_app.name)) {
                        exists = true;
                        break;
                    }
                }
                
                if (!exists) {
                    try self.apps.append(.{
                        .name = try self.allocator.dupe(u8, app.name),
                        .path = try self.allocator.dupe(u8, app.path),
                        .args = try self.allocator.dupe(u8, app.args),
                        .icon = try self.allocator.dupe(u8, app.icon),
                        .source = app.source,
                        .usage = app.usage,
                    });
                    std.debug.print("已添加从 Guest Server 获取的应用: {s}\n", .{app.name});
                }
            }
        }
    }

    fn addPresetApps(self: *Self) !void {
        // Windows Desktop
        try self.apps.append(self.allocator, .{
            .name = try self.allocator.dupe(u8, "⚙️ Windows Desktop"),
            .path = try self.allocator.dupe(u8, "WINDOWS_DESKTOP"),
            .args = try self.allocator.dupe(u8, ""),
            .icon = try self.allocator.dupe(u8, ""),
            .source = .internal,
            .usage = 0,
        });

        // Windows Explorer
        try self.apps.append(self.allocator, .{
            .name = try self.allocator.dupe(u8, "⚙️ Windows Explorer"),
            .path = try self.allocator.dupe(u8, "%windir%\\explorer.exe"),
            .args = try self.allocator.dupe(u8, ""),
            .icon = try self.allocator.dupe(u8, ""),
            .source = .internal,
            .usage = 0,
        });
    }
    
    fn fetchAppsFromGuestServer(self: *Self) ![]types.AppInfo {
        const guest_server_url = "http://127.0.0.1:7148/apps";
        
        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();
        
        // 构建请求
        var request = try client.open(.GET, try std.Uri.parse(guest_server_url), .{});
        defer request.deinit();
        
        // 设置超时
        try request.setTimeout(5000);
        
        // 发送请求
        try request.send();
        
        // 检查状态码
        if (request.response.status != .ok) {
            return error.ServerError;
        }
        
        // 读取响应体
        var body = try request.reader().readAllAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(body);
        
        // 解析 JSON 响应
        return try self.parseAppsJson(body);
    }
    
    fn parseAppsJson(self: *Self, json_data: []const u8) ![]types.AppInfo {
        // 解析 JSON 数据为应用列表
        var apps = std.ArrayList(types.AppInfo).init(self.allocator);
        errdefer apps.deinit();
        
        // 模拟解析结果
        try apps.append(.{
            .name = try self.allocator.dupe(u8, "计算器"),
            .path = try self.allocator.dupe(u8, "calc.exe"),
            .args = try self.allocator.dupe(u8, ""),
            .icon = try self.allocator.dupe(u8, "calc.png"),
            .source = .guest,
            .usage = 0,
        });
        
        try apps.append(.{
            .name = try self.allocator.dupe(u8, "画图"),
            .path = try self.allocator.dupe(u8, "mspaint.exe"),
            .args = try self.allocator.dupe(u8, ""),
            .icon = try self.allocator.dupe(u8, "mspaint.png"),
            .source = .guest,
            .usage = 0,
        });
        
        return apps.toOwnedSlice();
    }

    /// 添加自定义应用
    pub fn addCustomApp(self: *Self, name: []const u8, path: []const u8, args: []const u8, icon: []const u8) !void {
        try self.apps.append(self.allocator, .{
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
        std.debug.print("保存应用使用统计\n", .{});
        
        // 创建或打开文件
        const file = try std.fs.cwd().createFile(self.usage_file_path, .{});
        defer file.close();

        // 序列化应用使用统计到 JSON
        const json = try self.serializeUsageToJson();
        defer self.allocator.free(json);
        
        try file.writeAll(json);
        
        std.debug.print("应用使用统计已保存到 {s}\n", .{self.usage_file_path});
    }
    
    fn serializeUsageToJson(self: *Self) ![]u8 {
        // 创建 JSON 对象
        var obj = std.json.ObjectMap.init(self.allocator);
        defer obj.deinit();
        
        // 添加应用使用统计
        for (self.apps.items) |app| {
            if (app.usage > 0) {
                try obj.put(app.name, try std.json.Value.fromInteger(app.usage));
            }
        }
        
        // 创建一个包含元数据和应用统计的最终对象
        var result_obj = std.json.ObjectMap.init(self.allocator);
        defer result_obj.deinit();
        
        // 添加应用使用列表
        try result_obj.put("apps", try std.json.Value.fromObject(obj));
        
        // 添加元数据
        try result_obj.put("total_apps", try std.json.Value.fromInteger(@intCast(i64, self.apps.items.len)));
        
        // 获取当前时间戳
        try result_obj.put("timestamp", try std.json.Value.fromInteger(@intCast(i64, std.time.milliTimestamp())));
        
        // 序列化为 JSON 字符串
        const result_value = try std.json.Value.fromObject(result_obj);
        defer result_value.deinit();
        
        return try std.json.stringifyAlloc(self.allocator, result_value, .{ .whitespace = .indent_2 });
    }

    /// 获取应用列表
    pub fn getApps(self: *Self) []const types.AppInfo {
        return self.apps.items;
    }
};
