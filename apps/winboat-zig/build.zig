// WinBoat-Zig 构建配置
// 许可证: MulanPSL-2.0

const std = @import("std");

pub fn build(b: *std.Build) void {
    // 获取标准优化选项和目标平台
    const optimize = b.standardOptimizeOption(.{});
    const target = b.resolveTargetQuery(.{});
    
    // 创建模块依赖关系
    const modules = createModules(b, target, optimize);

    // 创建可执行文件
    const exe = b.addExecutable(.{ 
        .name = "winboat-zig", 
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    // 配置可执行文件
    configureExecutable(exe, modules);

    // 安装可执行文件
    b.installArtifact(exe);
    
    // 配置安装目录
    const install_dir = b.getInstallDirectory(.prefix);
    std.log.info("安装目录: {s}", .{install_dir});

    // 创建运行步骤
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "运行 WinBoat-Zig");
    run_step.dependOn(&run_cmd.step);

    // 配置测试
    configureTests(b, target, optimize, modules);
    
    // 添加构建选项
    addBuildOptions(b, exe);
}

fn createModules(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) std.StringHashMap(*std.Build.Module) {
    var modules = std.StringHashMap(*std.Build.Module).init(b.allocator);
    
    // 配置模块
    const config_types_mod = b.createModule(.{ 
        .root_source_file = b.path("src/config/types.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    const config_store_mod = b.createModule(.{ 
        .root_source_file = b.path("src/config/store.zig"),
        .target = target,
        .optimize = optimize,
        .dependencies = &.{
            .{ .name = "types", .module = config_types_mod },
        },
    });
    
    const container_manager_mod = b.createModule(.{ 
        .root_source_file = b.path("src/container/manager.zig"),
        .target = target,
        .optimize = optimize,
        .dependencies = &.{
            .{ .name = "types", .module = config_types_mod },
        },
    });
    
    const guest_server_mod = b.createModule(.{ 
        .root_source_file = b.path("src/guest/server.zig"),
        .target = target,
        .optimize = optimize,
        .dependencies = &.{
            .{ .name = "types", .module = config_types_mod },
        },
    });
    
    const app_manager_mod = b.createModule(.{ 
        .root_source_file = b.path("src/app/manager.zig"),
        .target = target,
        .optimize = optimize,
        .dependencies = &.{
            .{ .name = "types", .module = config_types_mod },
        },
    });
    
    // 添加到模块映射
    modules.put("config_types", config_types_mod) catch unreachable;
    modules.put("config_store", config_store_mod) catch unreachable;
    modules.put("container_manager", container_manager_mod) catch unreachable;
    modules.put("guest_server", guest_server_mod) catch unreachable;
    modules.put("app_manager", app_manager_mod) catch unreachable;
    
    return modules;
}

fn configureExecutable(exe: *std.Build.Step.Compile, modules: std.StringHashMap(*std.Build.Module)) void {
    // 添加模块依赖
    inline for ([_][]const u8{"config_types", "config_store", "container_manager", "guest_server", "app_manager"}) |mod_name| {
        const module = modules.get(mod_name).?;
        exe.root_module.addImport(mod_name, module);
    }
    
    // 配置链接选项
    exe.linkLibC();
    
    // 根据目标平台配置
    if (exe.target.isWindows()) {
        // Windows 特定配置
        exe.linkSystemLibrary("ws2_32"); // Windows Socket
        exe.linkSystemLibrary("user32"); // Windows API
    }
}

fn configureTests(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, modules: std.StringHashMap(*std.Build.Module)) void {
    // 创建测试模块
    const test_mod = b.createModule(.{ 
        .root_source_file = b.path("src/test.zig"), 
        .target = target, 
        .optimize = optimize,
        .dependencies = &[_\]std.Build.ModuleDependency{
            .{ .name = "main", .module = b.createModule(.{ .root_source_file = b.path("src/main.zig") }) },
            .{ .name = "config_types", .module = modules.get("config_types").? },
            .{ .name = "config_store", .module = modules.get("config_store").? },
            .{ .name = "container_manager", .module = modules.get("container_manager").? },
            .{ .name = "guest_server", .module = modules.get("guest_server").? },
            .{ .name = "app_manager", .module = modules.get("app_manager").? },
        },
    });

    // 创建测试步骤
    const unit_tests = b.addTest(.{ 
        .root_module = test_mod,
        .target = target,
        .optimize = optimize,
    });
    
    // 配置测试链接选项
    if (unit_tests.target.isWindows()) {
        unit_tests.linkSystemLibrary("ws2_32");
        unit_tests.linkSystemLibrary("user32");
    }

    const run_unit_tests = b.addRunArtifact(unit_tests);
    
    // 添加测试过滤选项
    if (b.args) |args| {
        run_unit_tests.addArgs(args);
    }
    
    const test_step = b.step("test", "运行单元测试");
    test_step.dependOn(&run_unit_tests.step);
    
    // 添加单独的集成测试步骤
    const integration_test_step = b.step("test-integration", "运行集成测试");
    integration_test_step.dependOn(&run_unit_tests.step);
}

fn addBuildOptions(b: *std.Build, exe: *std.Build.Step.Compile) void {
    // 创建构建选项
    const options = b.addOptions();
    
    // 设置版本信息
    options.addOption([]const u8, "version", "0.1.0");
    options.addOption([]const u8, "build_date", @as([]const u8, @import("builtin").build_date);
    options.addOption([]const u8, "compiler_version", @as([]const u8, @import("builtin").zig_version.toString());
    
    // 添加调试选项
    const enable_debug = b.option(bool, "enable-debug", "启用调试输出") orelse false;
    options.addOption(bool, "enable_debug", enable_debug);
    
    // 将选项添加到可执行文件
    exe.root_module.addOptions("build_options", options);
}
