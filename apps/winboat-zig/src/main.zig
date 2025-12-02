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
        
        // 获取应用信息
        const app = try self.getAppByName(app_name) orelse return error.AppNotFound;
        
        // 检查虚拟机是否正在运行
        if (self.container_mgr) |mgr| {
            if (!mgr.isRunning()) {
                std.debug.print("虚拟机未运行，正在启动...\n", .{});
                try mgr.start();
            }
            
            // 调用 RDP 客户端连接虚拟机
            try self.startRdpConnection(app);
        }
        
        // 更新应用使用统计
        if (self.app_mgr) |mgr| {
            try mgr.incrementUsage(app_name);
            try mgr.saveUsage();
        }
        
        std.debug.print("应用 {s} 启动成功\n", .{app_name});
    }
    
    fn getAppByName(self: *Self, app_name: []const u8) !?@import("config/types.zig").AppInfo {
        if (self.app_mgr) |mgr| {
            const apps = try mgr.getApps();
            
            for (apps) |app| {
                if (std.mem.eql(u8, app.name, app_name)) {
                    return app;
                }
            }
        }
        
        return null;
    }
    
    fn startRdpConnection(self: *Self, app: @import("config/types.zig").AppInfo) !void {
        const config = self.config_store.getConfig();
        
        // 根据不同平台选择合适的 RDP 客户端
        if (std.Target.current.os.tag == .windows) {
            try self.startWindowsRdpClient(app, config);
        } else if (std.Target.current.os.tag == .linux) {
            try self.startLinuxRdpClient(app, config);
        } else {
            // 其他平台使用默认的 RDP 客户端
            try self.startGenericRdpClient(app, config);
        }
    }
    
    fn startWindowsRdpClient(self: *Self, app: @import("config/types.zig").AppInfo, config: @import("config/types.zig").WinboatConfig) !void {
        // 使用 Windows 内置的 mstsc 客户端
        var mstsc_args = std.ArrayList([]const u8).init(self.allocator);
        defer mstsc_args.deinit();
        
        try mstsc_args.append("mstsc.exe");
        try mstsc_args.append("/v");
        try mstsc_args.appendFmt("127.0.0.1:{d}", .{7148});
        
        // 如果应用有特定路径，可以通过 /app 参数传递
        if (app.path.len > 0 and !std.mem.eql(u8, app.path, "explorer.exe")) {
            // 创建临时 RDP 文件
            const temp_dir = try std.fs.getTempDir();
            const rdp_file = try temp_dir.createFile("winboat_session.rdp", .{});
            defer rdp_file.close();
            
            try rdp_file.writer().print(
                "full address:s:127.0.0.1:{d}\n" ++
                "username:s:{s}\n" ++
                "password:s:{s}\n" ++
                "remoteapplicationprogram:s:{s}\n" ++
                "remoteapplicationmode:i:1\n",
                .{7148, config.rdp.username, config.rdp.password, app.path}
            );
            
            // 启动 mstsc 并指定 RDP 文件
            try mstsc_args.append(try temp_dir.realpathAlloc(self.allocator, "winboat_session.rdp"));
        }
        
        // 启动 mstsc 进程
        const process = try std.process.Child.init(mstsc_args.items, self.allocator);
        process.stdout_behavior = .Ignore;
        process.stderr_behavior = .Ignore;
        process.stdin_behavior = .Ignore;
        
        try process.spawn();
    }
    
    fn startLinuxRdpClient(self: *Self, app: @import("config/types.zig").AppInfo, config: @import("config/types.zig").WinboatConfig) !void {
        // 检查是否安装了常用的 RDP 客户端
        const clients = [_][]const u8{"remmina", "rdesktop", "xfreerdp"};
        
        for (clients) |client| {
            if (try self.isCommandAvailable(client)) {
                if (std.mem.eql(u8, client, "xfreerdp")) {
                    // 使用 xfreerdp
                    var args = std.ArrayList([]const u8).init(self.allocator);
                    defer args.deinit();
                    
                    try args.append("xfreerdp");
                    try args.appendFmt("/v:127.0.0.1:{d}", .{7148});
                    try args.appendFmt("/u:{s}", .{config.rdp.username});
                    try args.appendFmt("/p:{s}", .{config.rdp.password});
                    
                    // 如果应用有特定路径
                    if (app.path.len > 0) {
                        try args.append("/app");
                        try args.appendFmt("/app-path:{s}", .{app.path});
                    }
                    
                    try args.append("/cert-ignore");
                    try args.append("/sec:tls");
                    
                    const process = try std.process.Child.init(args.items, self.allocator);
                    try process.spawn();
                    process.detach();
                    return;
                } else if (std.mem.eql(u8, client, "rdesktop")) {
                    // 使用 rdesktop
                    var args = std.ArrayList([]const u8).init(self.allocator);
                    defer args.deinit();
                    
                    try args.append("rdesktop");
                    try args.appendFmt("-u {s}", .{config.rdp.username});
                    try args.appendFmt("-p {s}", .{config.rdp.password});
                    try args.appendFmt("127.0.0.1:{d}", .{7148});
                    
                    const process = try std.process.Child.init(args.items, self.allocator);
                    try process.spawn();
                    process.detach();
                    return;
                }
            }
        }
        
        // 如果没有找到 RDP 客户端，提示用户
        std.debug.print("未找到可用的 RDP 客户端，请安装 xfreerdp、rdesktop 或 remmina\n", .{});
        return error.RdpClientNotFound;
    }
    
    fn startGenericRdpClient(self: *Self, app: @import("config/types.zig").AppInfo, config: @import("config/types.zig").WinboatConfig) !void {
        std.debug.print("连接到 RDP 服务器: 127.0.0.1:{d}\n", .{7148});
        std.debug.print("应用路径: {s}\n", .{app.path});
        return error.UnsupportedPlatform;
    }
    
    fn isCommandAvailable(self: *Self, command: []const u8) !bool {
        var process = std.process.Child.init(
            &[_][]const u8{"which", command},
            self.allocator
        );
        
        process.stdout_behavior = .Ignore;
        process.stderr_behavior = .Ignore;
        
        try process.spawn();
        const result = try process.wait();
        
        return result == .Exited and result.Exited == 0;
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
    // 简化为无限循环保持程序运行
    while (true) {}
    // 注意：这里不会执行到下面的stop，实际应用中应该有事件循环和信号处理

    try winboat.stop();
}
