// WinBoat-Zig 主入口
// 许可证: MulanPSL-2.0

const std = @import("std");
const ConfigStore = @import("config/store.zig").ConfigStore;
const ContainerManager = @import("container/manager.zig").ContainerManager;
const GuestServer = @import("guest/server.zig").GuestServer;
const AppManager = @import("app/manager.zig").AppManager;

pub const WinboatZig = struct {
    allocator: std.mem.Allocator,
    config_store: ConfigStore,
    container_mgr: ?*ContainerManager,
    guest_server: ?*GuestServer,
    app_mgr: ?*AppManager,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        const config_path = "/opt/uya/winboat/config.json";
        var config_store = try ConfigStore.init(allocator, config_path);
        try config_store.load();

        return Self{
            .allocator = allocator,
            .config_store = config_store,
            .container_mgr = null,
            .guest_server = null,
            .app_mgr = null,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.container_mgr) |mgr| {
            mgr.deinit();
            self.allocator.destroy(mgr);
        }
        if (self.guest_server) |server| {
            server.deinit();
            self.allocator.destroy(server);
        }
        if (self.app_mgr) |mgr| {
            mgr.deinit();
            self.allocator.destroy(mgr);
        }
        self.config_store.deinit();
    }

    /// 初始化所有管理器
    pub fn initManagers(self: *Self) !void {
        const config = self.config_store.getConfig();

        // 初始化容器管理器
        const container_mgr = try self.allocator.create(ContainerManager);
        container_mgr.* = try ContainerManager.init(
            self.allocator,
            config.container_runtime,
            "winboat-windows",
        );
        self.container_mgr = container_mgr;

        // 初始化 Guest Server
        const guest_server = try self.allocator.create(GuestServer);
        guest_server.* = GuestServer.init(self.allocator, 7148);
        self.guest_server = guest_server;

        // 初始化应用管理器
        const app_mgr = try self.allocator.create(AppManager);
        const usage_path = "/opt/uya/winboat/appUsage.json";
        app_mgr.* = try AppManager.init(self.allocator, usage_path);
        self.app_mgr = app_mgr;
    }

    /// 启动 WinBoat
    pub fn start(self: *Self) !void {
        std.debug.print("WinBoat-Zig 启动中...\n", .{});

        // 初始化管理器
        try self.initManagers();

        // 启动容器
        if (self.container_mgr) |mgr| {
            try mgr.start();
        }

        // 启动 Guest Server
        if (self.guest_server) |server| {
            try server.start();
        }

        // 同步应用列表
        if (self.app_mgr) |mgr| {
            try mgr.syncApps();
        }

        std.debug.print("WinBoat-Zig 启动完成\n", .{});
    }

    /// 停止 WinBoat
    pub fn stop(self: *Self) !void {
        std.debug.print("WinBoat-Zig 停止中...\n", .{});

        // 停止 Guest Server
        if (self.guest_server) |server| {
            try server.stop();
        }

        // 停止容器
        if (self.container_mgr) |mgr| {
            try mgr.stop();
        }

        std.debug.print("WinBoat-Zig 已停止\n", .{});
    }

    /// 获取应用列表
    pub fn getApps(self: *Self) ![]const @import("config/types.zig").AppInfo {
        if (self.app_mgr) |mgr| {
            return mgr.getApps();
        }
        return &[_]@import("config/types.zig").AppInfo{};
    }

    /// 启动应用
    pub fn launchApp(self: *Self, app_name: []const u8) !void {
        std.debug.print("启动应用: {s}\n", .{app_name});

        // TODO: 实现 RDP 客户端调用
        // 使用 FreeRDP 或实现原生 RDP 协议

        // 增加使用计数
        if (self.app_mgr) |mgr| {
            try mgr.incrementUsage(app_name);
        }
    }

    /// 获取系统指标
    pub fn getMetrics(self: *Self) !@import("config/types.zig").Metrics {
        if (self.guest_server) |server| {
            return try server.getMetrics();
        }
        return error.GuestServerNotRunning;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var winboat = try WinboatZig.init(allocator);
    defer winboat.deinit();

    try winboat.start();

    // 主循环
    std.debug.print("WinBoat-Zig 运行中，按 Ctrl+C 退出...\n", .{});
    
    // 简单等待（实际应用中应该有事件循环）
    std.time.sleep(std.time.ns_per_s * 3600);

    try winboat.stop();
}
