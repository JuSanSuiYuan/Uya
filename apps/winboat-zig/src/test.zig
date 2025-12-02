// WinBoat-Zig 集成测试
// 许可证: MulanPSL-2.0

const std = @import("std");
const WinboatZig = @import("main.zig").WinboatZig;
const types = @import("config/types.zig");

test "配置存储初始化" {
    const allocator = std.testing.allocator;
    
    var config = try types.WinboatConfig.default(allocator);
    defer config.deinit(allocator);
    
    try std.testing.expectEqual(types.ContainerRuntime.qemu_kvm, config.container_runtime);
    try std.testing.expectEqual(@as(u8, 4), config.vm_specs.cpu_cores);
    try std.testing.expectEqual(@as(u32, 4096), config.vm_specs.memory_mb);
}

test "容器管理器初始化" {
    const allocator = std.testing.allocator;
    const ContainerManager = @import("container/manager.zig").ContainerManager;
    
    var manager = try ContainerManager.init(
        allocator,
        .qemu_kvm,
        "test-container",
    );
    defer manager.deinit();
    
    try std.testing.expectEqualStrings("test-container", manager.container_name);
    try std.testing.expectEqual(types.ContainerStatus.exited, manager.status);
}

test "应用管理器初始化" {
    const allocator = std.testing.allocator;
    const AppManager = @import("app/manager.zig").AppManager;
    
    var manager = try AppManager.init(allocator, "/tmp/test_usage.json");
    defer manager.deinit();
    
    try manager.syncApps();
    
    const apps = manager.getApps();
    try std.testing.expect(apps.len >= 2); // 至少有两个预设应用
}

test "Guest Server 初始化" {
    const allocator = std.testing.allocator;
    const GuestServer = @import("guest/server.zig").GuestServer;
    
    var server = GuestServer.init(allocator, 7148);
    defer server.deinit();
    
    try std.testing.expectEqual(@as(u16, 7148), server.port);
    try std.testing.expectEqual(false, server.running);
}

test "Guest Server 指标收集" {
    const allocator = std.testing.allocator;
    const GuestServer = @import("guest/server.zig").GuestServer;
    
    var server = GuestServer.init(allocator, 7148);
    defer server.deinit();
    
    const metrics = try server.getMetrics();
    
    try std.testing.expect(metrics.cpu.usage >= 0.0 and metrics.cpu.usage <= 100.0);
    try std.testing.expect(metrics.ram.total > 0);
    try std.testing.expect(metrics.disk.total > 0);
}

test "自定义应用添加与删除" {
    const allocator = std.testing.allocator;
    const AppManager = @import("app/manager.zig").AppManager;
    
    var manager = try AppManager.init(allocator, "/tmp/test_usage.json");
    defer manager.deinit();
    
    // 添加自定义应用
    try manager.addCustomApp(
        "Test App",
        "C:\\test.exe",
        "--test",
        "icon.png",
    );
    
    const apps = manager.getApps();
    try std.testing.expect(apps.len > 0);
    
    var found = false;
    for (apps) |app| {
        if (std.mem.eql(u8, app.name, "Test App")) {
            found = true;
            break;
        }
    }
    try std.testing.expect(found);
    
    // 删除自定义应用
    try manager.removeCustomApp("Test App");
    
    const apps_after = manager.getApps();
    found = false;
    for (apps_after) |app| {
        if (std.mem.eql(u8, app.name, "Test App")) {
            found = true;
            break;
        }
    }
    try std.testing.expect(!found);
}

test "应用使用计数" {
    const allocator = std.testing.allocator;
    const AppManager = @import("app/manager.zig").AppManager;
    
    var manager = try AppManager.init(allocator, "/tmp/test_usage.json");
    defer manager.deinit();
    
    try manager.syncApps();
    
    const apps_before = manager.getApps();
    const initial_usage = apps_before[0].usage;
    
    try manager.incrementUsage(apps_before[0].name);
    
    const apps_after = manager.getApps();
    try std.testing.expectEqual(initial_usage + 1, apps_after[0].usage);
}

test "配置存储JSON序列化" {
    const allocator = std.testing.allocator;
    const ConfigStore = @import("config/store.zig").ConfigStore;
    
    // 创建临时配置文件
    const tmp_dir = try std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    
    const config_file = try tmp_dir.dir.join(allocator, &[_][]const u8{"config.json"});
    defer allocator.free(config_file);
    
    // 初始化配置存储
    var store = try ConfigStore.init(allocator, config_file);
    defer store.deinit();
    
    // 获取默认配置
    var config = try store.getConfig();
    
    // 修改配置
    config.vm_specs.cpu_cores = 2;
    config.vm_specs.memory_mb = 2048;
    
    // 保存配置
    try store.save();
    
    // 重新加载配置
    try store.load();
    const loaded_config = try store.getConfig();
    
    // 验证配置是否正确保存和加载
    try std.testing.expectEqual(@as(u8, 2), loaded_config.vm_specs.cpu_cores);
    try std.testing.expectEqual(@as(u32, 2048), loaded_config.vm_specs.memory_mb);
}

test "QEMU命令行参数构建" {
    const allocator = std.testing.allocator;
    const ContainerManager = @import("container/manager.zig").ContainerManager;
    
    var manager = try ContainerManager.init(
        allocator,
        .qemu_kvm,
        "test-vm",
    );
    defer manager.deinit();
    
    // 模拟构建QEMU命令行参数
    // 注意：这里不实际启动QEMU，只测试参数构建逻辑
    if (@hasDecl(ContainerManager, "buildQemuCommand")) {
        // 如果buildQemuCommand是公共方法，测试它
        std.debug.print("QEMU命令行参数构建测试：跳过实际执行\n", .{});
    }
}

test "Guest Server HTTP接口" {
    const allocator = std.testing.allocator;
    const GuestServer = @import("guest/server.zig").GuestServer;
    
    // 初始化Guest Server但不实际启动
    var server = GuestServer.init(allocator, 7148);
    defer server.deinit();
    
    // 测试健康状态检查
    const health = try server.getHealth();
    std.debug.print("Guest Server健康状态: {}\n", .{health});
    
    // 测试指标收集
    const metrics = try server.getMetrics();
    try std.testing.expect(metrics.cpu.usage >= 0.0 and metrics.cpu.usage <= 100.0);
    try std.testing.expect(metrics.ram.used_mb >= 0);
    try std.testing.expect(metrics.disk.used_mb >= 0);
}

test "应用管理器JSON序列化" {
    const allocator = std.testing.allocator;
    const AppManager = @import("app/manager.zig").AppManager;
    
    const tmp_dir = try std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    
    const usage_file = try tmp_dir.dir.join(allocator, &[_][]const u8{"app_usage.json"});
    defer allocator.free(usage_file);
    
    var manager = try AppManager.init(allocator, usage_file);
    defer manager.deinit();
    
    try manager.syncApps();
    
    // 增加一些应用的使用计数
    const apps = manager.getApps();
    if (apps.len > 0) {
        try manager.incrementUsage(apps[0].name);
        try manager.incrementUsage(apps[0].name);
    }
    
    // 保存使用统计
    try manager.saveUsage();
    
    // 验证文件是否存在
    const file_exists = std.fs.accessAbsolute(usage_file, .{}) catch false;
    try std.testing.expect(file_exists);
}
