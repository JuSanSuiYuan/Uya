// WinBoat-Zig 容器管理器
// 许可证: MulanPSL-2.0

const std = @import("std");
const types = @import("../config/types.zig");

pub const ContainerManager = struct {
    allocator: std.mem.Allocator,
    runtime: types.ContainerRuntime,
    container_name: []const u8,
    status: types.ContainerStatus,
    config_store: *types.ConfigStore,
    pid_file_path: ?[]const u8 = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, runtime: types.ContainerRuntime, container_name: []const u8, config_store: *types.ConfigStore) !Self {
        return Self{
            .allocator = allocator,
            .runtime = runtime,
            .container_name = try allocator.dupe(u8, container_name),
            .status = .exited,
            .config_store = config_store,
            .pid_file_path = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.container_name);
        if (self.pid_file_path) |path| {
            self.allocator.free(path);
        }
    }

    /// 启动容器
    pub fn start(self: *Self) !void {
        std.debug.print("启动容器: {s}\n", .{self.container_name});
        
        switch (self.runtime) {
            .qemu_kvm => try self.startQemuKvm(),
            .docker => try self.startDocker(),
            .podman => try self.startPodman(),
        }
        
        self.status = .running;
    }

    /// 停止容器
    pub fn stop(self: *Self) !void {
        std.debug.print("停止容器: {s}\n", .{self.container_name});
        
        switch (self.runtime) {
            .qemu_kvm => try self.stopQemuKvm(),
            .docker => try self.execCommand(&[_][]const u8{ "docker", "stop", self.container_name }),
            .podman => try self.execCommand(&[_][]const u8{ "podman", "stop", self.container_name }),
        }
        
        self.status = .exited;
    }

    /// 暂停容器
    pub fn pause(self: *Self) !void {
        std.debug.print("暂停容器: {s}\n", .{self.container_name});
        
        switch (self.runtime) {
            .qemu_kvm => try self.pauseQemuKvm(),
            .docker => try self.execCommand(&[_][]const u8{ "docker", "pause", self.container_name }),
            .podman => try self.execCommand(&[_][]const u8{ "podman", "pause", self.container_name }),
        }
        
        self.status = .paused;
    }

    /// 恢复容器
    pub fn unpause(self: *Self) !void {
        std.debug.print("恢复容器: {s}\n", .{self.container_name});
        
        switch (self.runtime) {
            .qemu_kvm => try self.unpauseQemuKvm(),
            .docker => try self.execCommand(&[_][]const u8{ "docker", "unpause", self.container_name }),
            .podman => try self.execCommand(&[_][]const u8{ "podman", "unpause", self.container_name }),
        }
        
        self.status = .running;
    }

    /// 获取容器状态
    pub fn getStatus(self: *Self) !types.ContainerStatus {
        // TODO: 实际查询容器状态
        return self.status;
    }

    // Docker 特定方法
    fn startDocker(self: *Self) !void {
        try self.execCommand(&[_][]const u8{ "docker", "start", self.container_name });
    }
    
    // Podman 特定方法
    fn startPodman(self: *Self) !void {
        try self.execCommand(&[_][]const u8{ "podman", "start", self.container_name });
    }
    
    // QEMU/KVM 特定方法
    fn startQemuKvm(self: *Self) !void {
        const config = self.config_store.getConfig();
        
        // 构建 QEMU 命令行参数
        var args = std.ArrayList([]const u8).init(self.allocator);
        defer args.deinit();
        
        // 基本 QEMU 命令
        try args.append("qemu-system-x86_64");
        
        // VM 规格
        try args.append("-smp");
        const cpu_cores_str = try std.fmt.allocPrint(self.allocator, "{d}", .{config.vm_specs.cpu_cores});
        try args.append(cpu_cores_str);
        defer self.allocator.free(cpu_cores_str);
        
        try args.append("-m");
        const memory_str = try std.fmt.allocPrint(self.allocator, "{d}M", .{config.vm_specs.memory_mb});
        try args.append(memory_str);
        defer self.allocator.free(memory_str);
        
        // 启用 KVM
        try args.append("-enable-kvm");
        
        // 硬盘设置
        const disk_path = try std.fmt.allocPrint(self.allocator, "{s}/windows.qcow2", .{config.storage_dir});
        defer self.allocator.free(disk_path);
        
        try args.append("-drive");
        const drive_args = try std.fmt.allocPrint(self.allocator, "file={s},format=qcow2,if=virtio", .{disk_path});
        try args.append(drive_args);
        defer self.allocator.free(drive_args);
        
        // 网络设置
        try args.append("-netdev");
        try args.append("user,id=net0,hostfwd=tcp::3389-:3389,hostfwd=tcp::7148-:7148");
        try args.append("-device");
        try args.append("virtio-net-pci,netdev=net0");
        
        // 显示设置
        try args.append("-display");
        try args.append("none"); // 无图形界面，通过 RDP 连接
        
        // 声音设置
        if (config.rdp.sound_enabled) {
            try args.append("-soundhw");
            try args.append("ac97");
        }
        
        // 其他设置
        try args.append("-name");
        try args.append("WinBoat-Windows-VM");
        
        try args.append("-daemonize"); // 后台运行
        
        // 保存 PID 文件路径
        // 先释放旧的路径（如果存在）
        if (self.pid_file_path) |old_path| {
            self.allocator.free(old_path);
        }
        
        self.pid_file_path = try std.fmt.allocPrint(self.allocator, "{s}/winboat-vm.pid", .{config.storage_dir});
        
        try args.append("-pidfile");
        try args.append(self.pid_file_path.?);
        
        // 执行 QEMU 命令
        std.debug.print("启动 QEMU/KVM 虚拟机: {s}\n", .{args.items[0]});
        try self.execCommand(args.items);
        
        // 状态更新由外部start方法处理
    }

    fn stopQemuKvm(self: *Self) !void {
        if (self.pid_file_path) |pid_path| {
            // 读取 PID 文件
            const pid_file = std.fs.cwd().openFile(pid_path, .{}) catch |err| {
                if (err == error.FileNotFound) {
                    std.debug.print("PID 文件不存在，可能虚拟机未运行\n", .{});
                    // 清理状态
                    self.allocator.free(pid_path);
                    self.pid_file_path = null;
                    return error.VirtualMachineNotRunning;
                }
                return err;
            };
            defer pid_file.close();
            
            const pid_str = try pid_file.readToEndAlloc(self.allocator, 1024);
            defer self.allocator.free(pid_str);
            
            const pid = try std.fmt.parseInt(i32, std.mem.trim(u8, pid_str, " \r\n"), 10);
            
            // 终止进程
            try self.killProcess(pid);
            
            // 删除 PID 文件
            try std.fs.cwd().deleteFile(pid_path) catch |err| {
                std.debug.print("无法删除 PID 文件: {s}，错误: {}", .{pid_path, err});
                // 继续执行，不中断流程
            };
            
            // 清理状态
            self.allocator.free(pid_path);
            self.pid_file_path = null;
            
            std.debug.print("已停止 QEMU/KVM 虚拟机 (PID: {d})\n", .{pid});
        } else {
            std.debug.print("未找到 PID 文件路径，无法停止虚拟机\n", .{});
        }
    }

    fn pauseQemuKvm(self: *Self) !void {
        if (self.pid_file_path) |pid_path| {
            // 读取 PID 文件
            const pid_file = std.fs.cwd().openFile(pid_path, .{}) catch |err| {
                if (err == error.FileNotFound) {
                    return error.VirtualMachineNotRunning;
                }
                return err;
            };
            defer pid_file.close();
            
            const pid_str = try pid_file.readToEndAlloc(self.allocator, 1024);
            defer self.allocator.free(pid_str);
            
            const pid = try std.fmt.parseInt(i32, pid_str, 10);
            
            // 发送 SIGSTOP 信号
            const handle = try std.os.getProcessHandle(pid);
            try std.os.kill(handle, std.os.SIG.STOP);
            
            self.status = .paused;
            std.debug.print("已暂停 QEMU/KVM 虚拟机 (PID: {d})\n", .{pid});
        } else {
            return error.VirtualMachineNotRunning;
        }
    }

    fn unpauseQemuKvm(self: *Self) !void {
        if (self.pid_file_path) |pid_path| {
            // 读取 PID 文件
            const pid_file = std.fs.cwd().openFile(pid_path, .{}) catch |err| {
                if (err == error.FileNotFound) {
                    return error.VirtualMachineNotRunning;
                }
                return err;
            };
            defer pid_file.close();
            
            const pid_str = try pid_file.readToEndAlloc(self.allocator, 1024);
            defer self.allocator.free(pid_str);
            
            const pid = try std.fmt.parseInt(i32, pid_str, 10);
            
            // 发送 SIGCONT 信号
            const handle = try std.os.getProcessHandle(pid);
            try std.os.kill(handle, std.os.SIG.CONT);
            
            self.status = .running;
            std.debug.print("已恢复 QEMU/KVM 虚拟机 (PID: {d})\n", .{pid});
        } else {
            return error.VirtualMachineNotRunning;
        }
    }

    // 通用命令执行
    fn execCommand(self: *Self, args: []const []const u8) !void {
        var child = std.process.Child.init(args, self.allocator);
        defer child.deinit();
        
        // 设置错误输出捕获
        var stderr = std.ArrayList(u8).init(self.allocator);
        defer stderr.deinit();
        
        child.stderr_behavior = .Pipe;
        
        try child.spawn();
        
        // 读取标准错误
        if (child.stderr) |stderr_file| {
            _ = try stderr_file.readAllAlloc(stderr.allocator, 4096);
            stderr_file.close();
        }
        
        const result = try child.wait();
        
        if (result != .Exited or result.Exited != 0) {
            const error_msg = if (stderr.items.len > 0) 
                try std.fmt.allocPrint(self.allocator, "命令执行失败: {s}, 错误: {s}", .{args[0], stderr.items})
            else
                try std.fmt.allocPrint(self.allocator, "命令执行失败: {s}, 退出码: {d}", .{args[0], result.Exited});
            defer self.allocator.free(error_msg);
            
            std.debug.print("{s}\n", .{error_msg});
            return error.CommandFailed;
        }
    }
    
    fn killProcess(self: *Self, pid: i32) !void {
        // 发送 SIGTERM 信号
        const handle = try std.os.getProcessHandle(pid);
        try std.os.kill(handle, std.os.SIG.TERM);
        
        // 等待进程终止
        var timeout: u32 = 0;
        while (timeout < 5000) : (timeout += 100) {
            std.time.sleep(100 * std.time.ns_per_ms);
            
            // 检查进程是否还在运行
            const proc_exists = std.os.kill(handle, 0) catch |err|
                if (err == error.PermissionDenied) false else return err;
            
            if (!proc_exists) break;
        }
        
        // 如果进程仍在运行，强制终止
        const proc_still_exists = std.os.kill(handle, 0) catch |err|
            if (err == error.PermissionDenied) false else return err;
        
        if (proc_still_exists) {
            std.debug.print("进程 {d} 未响应 SIGTERM，尝试强制终止\n", .{pid});
            try std.os.kill(handle, std.os.SIG.KILL);
        }
        
        std.debug.print("进程 {d} 已终止\n", .{pid});
    }
};
