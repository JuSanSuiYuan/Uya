// WinBoat-Zig 配置存储
// 许可证: MulanPSL-2.0

const std = @import("std");
const types = @import("types.zig");

pub const ConfigStore = struct {
    allocator: std.mem.Allocator,
    config: types.WinboatConfig,
    config_path: []const u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config_path: []const u8) !Self {
        const config = try types.WinboatConfig.default(allocator);
        
        return Self{
            .allocator = allocator,
            .config = config,
            .config_path = try allocator.dupe(u8, config_path),
        };
    }

    pub fn deinit(self: *Self) void {
        self.config.deinit(self.allocator);
        self.allocator.free(self.config_path);
    }

    /// 从文件加载配置
    pub fn load(self: *Self) !void {
        const file = std.fs.cwd().openFile(self.config_path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                // 配置文件不存在，使用默认配置
                return;
            }
            return err;
        };
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(content);

        // TODO: 实现 JSON 解析
        _ = content;
    }

    /// 保存配置到文件
    pub fn save(self: *Self) !void {
        const file = try std.fs.cwd().createFile(self.config_path, .{});
        defer file.close();

        // TODO: 实现 JSON 序列化
        const json = "{}"; // 占位符
        try file.writeAll(json);
    }

    /// 获取配置引用
    pub fn getConfig(self: *Self) *types.WinboatConfig {
        return &self.config;
    }
};
