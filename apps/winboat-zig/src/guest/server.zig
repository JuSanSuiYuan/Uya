// WinBoat-Zig Guest Server
// 许可证: MulanPSL-2.0

const std = @import("std");
const types = @import("../config/types.zig");

pub const GuestServer = struct {
    allocator: std.mem.Allocator,
    port: u16,
    running: bool,
    listener: ?std.net.Listener = null,
    server_thread: ?std.Thread = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, port: u16) Self {
        return Self{
            .allocator = allocator,
            .port = port,
            .running = false,
            .listener = null,
            .server_thread = null,
        };
    }

    pub fn deinit(self: *Self) void {
        // 确保服务器停止
        if (self.running) {
            _ = self.stop() catch std.debug.print("停止服务器时出错\n", .{});
        }
        
        // 停止服务器线程
        if (self.server_thread) |thread| {
            thread.join();
            self.server_thread = null;
        }
        
        // 关闭监听器
        if (self.listener) |*listener| {
            listener.deinit();
            self.listener = null;
        }
    }
    
    /// 启动 Guest Server
    pub fn start(self: *Self) !void {
        std.debug.print("启动 Guest Server，监听端口: {d}\n", .{self.port});
        
        // 启动 HTTP 服务器
        try self.startHttpServer();
        
        self.running = true;
    }
    
    fn startHttpServer(self: *Self) !void {
        const address = try std.net.Address.parseIp("127.0.0.1", self.port);
        var listener = try address.listen(.{ .reuse_address = true });
        
        // 存储监听器，以便后续停止
        self.listener = listener;
        
        // 创建服务器线程
        const thread = try std.Thread.spawn(.{}, Self.httpServerThread, .{self});
        self.server_thread = thread;
        
        std.debug.print("Guest Server HTTP 服务已启动，监听端口 {d}\n", .{self.port});
    }
    
    fn httpServerThread(self: *Self) void {
        while (self.running) {
            // 接受连接
            const conn = self.listener.?.accept() catch |err| {
                if (err == error.ConnectionResetByPeer or err == error.ConnectionAborted) {
                    continue;
                } else if (self.running) {
                    std.debug.print("接受连接时出错: {}\n", .{err});
                    // 短暂睡眠避免CPU占用过高
                    std.time.sleep(100 * std.time.ns_per_ms);
                    continue;
                } else {
                    // 服务器停止时的错误，直接返回
                    return;
                }
            };
            
            // 为每个连接创建处理线程
            const handle_conn = std.Thread.spawn(.{}, Self.handleConnection, .{self, conn}) catch |err| {
                std.debug.print("创建连接处理线程失败: {}\n", .{err});
                conn.stream.close();
                continue;
            };
            handle_conn.detach();
        }
    }
    
    fn handleConnection(self: *Self, conn: std.net.Server.Connection) void {
        var buffer: [4096]u8 = undefined;
        const stream = conn.stream;
        defer stream.close();
        
        // 读取请求
        const read_bytes = stream.readAll(&buffer) catch |err| {
            std.debug.print("读取连接数据时出错: {}\n", .{err});
            return;
        };
        
        if (read_bytes == 0) return;
        
        // 解析 HTTP 请求路径
        const request = buffer[0..read_bytes];
        var path: ?[]const u8 = null;
        
        if (std.mem.indexOf(u8, request, "GET ")) |get_idx| {
            const path_start = get_idx + 4;
            if (std.mem.indexOf(u8, request[path_start..], " ")) |path_end| {
                path = request[path_start .. path_start + path_end];
            }
        }
        
        // 路由请求
        if (path) |p| {
            if (std.mem.eql(u8, p, "/health")) {
                self.serveHealthCheck(stream) catch |err| {
                    std.debug.print("处理健康检查时出错: {}\n", .{err});
                };
            } else if (std.mem.eql(u8, p, "/metrics")) {
                self.serveMetrics(stream) catch |err| {
                    std.debug.print("处理指标请求时出错: {}\n", .{err});
                };
            } else if (std.mem.eql(u8, p, "/apps")) {
                self.serveApps(stream) catch |err| {
                    std.debug.print("处理应用列表请求时出错: {}\n", .{err});
                };
            } else {
                self.serveNotFound(stream) catch |err| {
                    std.debug.print("处理404响应时出错: {}\n", .{err});
                };
            }
        } else {
            self.serveNotFound(stream) catch |err| {
                std.debug.print("处理无效请求时出错: {}\n", .{err});
            };
        }
    }
    
    fn serveHealthCheck(self: *Self, stream: anytype) !void {
        const health = self.getHealth();
        const response = try std.fmt.allocPrint(
            self.allocator,
            "HTTP/1.1 200 OK\r\n"
            "Content-Type: application/json\r\n"
            "Connection: close\r\n"
            "Content-Length: {d}\r\n"
            "\r\n"
            "{{\"healthy\":{}}}",
            .{if (health) 14 else 15, health}
        );
        defer self.allocator.free(response);
        
        try stream.writeAll(response) catch |err| {
            std.debug.print("写入健康检查响应失败: {}\n", .{err});
            return err;
        };
    }
    
    fn serveMetrics(self: *Self, stream: anytype) !void {
        const metrics = try self.getMetrics();
        
        // 构建 JSON 响应
        const response = try std.fmt.allocPrint(
            self.allocator,
            "HTTP/1.1 200 OK\r\n"
            "Content-Type: application/json\r\n"
            "Connection: close\r\n"
            "\r\n"
            "{{\"cpu\":{{\"usage\":{d:.1},\"frequency\":{d}}},\"ram\":{{\"total\":{d},\"used\":{d},\"percentage\":{d:.1}}},\"disk\":{{\"total\":{d},\"used\":{d},\"percentage\":{d:.1}}}}}\r\n",
            .{
                metrics.cpu.usage,
                metrics.cpu.frequency,
                metrics.ram.total,
                metrics.ram.used,
                metrics.ram.percentage,
                metrics.disk.total,
                metrics.disk.used,
                metrics.disk.percentage
            }
        );
        defer self.allocator.free(response);
        
        try stream.writeAll(response);
    }
    
    fn serveApps(self: *Self, stream: anytype) !void {
        // 返回应用列表
        const apps_json = "[{\"name\":\"Windows Desktop\",\"path\":\"explorer.exe\"},{\"name\":\"Windows Explorer\",\"path\":\"explorer.exe\"}]";
        const response = try std.fmt.allocPrint(
            self.allocator,
            "HTTP/1.1 200 OK\r\n"
            "Content-Type: application/json\r\n"
            "Connection: close\r\n"
            "Content-Length: {d}\r\n"
            "\r\n"
            "{s}",
            .{apps_json.len, apps_json}
        );
        defer self.allocator.free(response);
        
        try stream.writeAll(response);
    }
    
    fn serveNotFound(self: *Self, stream: anytype) !void {
        const response = 
            "HTTP/1.1 404 Not Found\r\n"
            "Content-Type: text/plain\r\n"
            "Connection: close\r\n"
            "\r\n"
            "404 Not Found\r\n";
        
        try stream.writeAll(response);
    }

    /// 停止 Guest Server
    pub fn stop(self: *Self) !void {
        std.debug.print("停止 Guest Server\n", .{});
        
        // 设置停止标志
        self.running = false;
        
        // 关闭监听器以中断 accept 调用
        if (self.listener) |*listener| {
            listener.deinit();
            self.listener = null;
        }
        
        // 等待服务器线程结束
        if (self.server_thread) |thread| {
            // 最多等待5秒
            const timeout = 5 * std.time.ns_per_s;
            const start = std.time.milliTimestamp();
            
            while (true) {
                // 非阻塞检查线程是否结束
                if (thread.joinable()) {
                    // 如果线程还在运行，尝试连接到自己的端口以中断accept
                    _ = std.Thread.spawn(.{}, Self.interruptAccept, .{self}) catch {};
                    
                    // 短暂睡眠后再次检查
                    std.time.sleep(100 * std.time.ns_per_ms);
                    
                    // 检查超时
                    if (std.time.milliTimestamp() - start > timeout / std.time.ns_per_ms) {
                        std.debug.print("服务器线程等待超时\n", .{});
                        break;
                    }
                } else {
                    // 线程已结束
                    self.server_thread = null;
                    break;
                }
            }
        }
        
        std.debug.print("Guest Server 已停止\n", .{});
    }
    
    fn interruptAccept(self: *Self) void {
        // 尝试连接到自己的端口以中断accept调用
        const address = std.net.Address.parseIp("127.0.0.1", self.port) catch return;
        _ = address.connectToHost(self.allocator, self.port, .{ .timeout = 500 }) catch {};
    }

    /// 获取健康状态
    pub fn getHealth(self: *Self) bool {
        if (!self.running) return false;
        
        // 检查 RDP 连接是否可用
        const rdp_available = self.checkRdpConnection() catch false;
        return rdp_available;
    }
    
    fn checkRdpConnection(self: *Self) !bool {
        // 尝试连接到默认的 RDP 端口
        const address = try std.net.Address.parseIp("127.0.0.1", 3389);
        
        const conn = address.connectToHost(self.allocator, 3389, .{ .timeout = 2000 }) catch |err|
            if (err == error.ConnectionRefused or err == error.ConnectionTimedOut) return false
            else return err;
        
        defer conn.stream.close();
        return true;
    }

    /// 获取系统指标
    pub fn getMetrics(self: *Self) !types.Metrics {
        // 收集各项指标，如果失败则使用默认值
        var metrics = types.Metrics{};
        
        // 收集 CPU 指标
        metrics.cpu = self.getCpuMetrics() catch |err| {
            std.debug.print("获取CPU指标失败: {}\n", .{err});
            types.CpuMetrics{ .usage = 40.0, .frequency = 3200 }
        };
        
        // 收集内存指标
        metrics.ram = self.getRamMetrics() catch |err| {
            std.debug.print("获取内存指标失败: {}\n", .{err});
            types.RamMetrics{ .total = 8192, .used = 3000, .percentage = 36.6 }
        };
        
        // 收集磁盘指标
        metrics.disk = self.getDiskMetrics() catch |err| {
            std.debug.print("获取磁盘指标失败: {}\n", .{err});
            types.DiskMetrics{ .total = 128, .used = 40, .percentage = 31.3 }
        };

        return metrics;
    }

    fn getCpuMetrics(self: *Self) !types.CpuMetrics {
        _ = self;
        var metrics = types.CpuMetrics{ .usage = 0.0, .frequency = 0 };
        
        // 在不同平台上使用不同的方法获取 CPU 信息
        if (std.Target.current.os.tag == .windows) {
            // Windows 平台获取 CPU 使用率
            // 这里使用模拟值，实际应用中应使用 Windows API
            metrics.usage = 45.2;
            metrics.frequency = 3400;
        } else {
            // Linux 平台，读取 /proc/stat
            const file = try std.fs.openFileAbsolute("/proc/stat", .{});
            defer file.close();
            
            var buf_reader = std.io.bufferedReader(file.reader());
            var in_stream = buf_reader.reader();
            
            var line_buf: [256]u8 = undefined;
            const line = try in_stream.readUntilDelimiterOrEof(&line_buf, '\n');
            
            if (line) |l| {
                if (std.mem.startsWith(u8, l, "cpu ")) {
                    var fields = std.mem.tokenize(u8, l[4..]);
                    
                    var user: u64 = 0;
                    var nice: u64 = 0;
                    var system: u64 = 0;
                    var idle: u64 = 0;
                    
                    if (fields.next()) |val| user = try std.fmt.parseInt(u64, val, 10);
                    if (fields.next()) |val| nice = try std.fmt.parseInt(u64, val, 10);
                    if (fields.next()) |val| system = try std.fmt.parseInt(u64, val, 10);
                    if (fields.next()) |val| idle = try std.fmt.parseInt(u64, val, 10);
                    
                    const total = user + nice + system + idle;
                    if (total > 0) {
                        metrics.usage = @as(f64, @floatFromInt(total - idle)) / @as(f64, @floatFromInt(total)) * 100.0;
                    }
                }
            }
            
            // 获取 CPU 频率
            const cpuinfo = try std.fs.openFileAbsolute("/proc/cpuinfo", .{});
            defer cpuinfo.close();
            
            var cpu_buf_reader = std.io.bufferedReader(cpuinfo.reader());
            var cpu_in_stream = cpu_buf_reader.reader();
            
            while (true) {
                var cpu_line_buf: [256]u8 = undefined;
                const cpu_line = try cpu_in_stream.readUntilDelimiterOrEof(&cpu_line_buf, '\n');
                
                if (cpu_line == null) break;
                
                if (std.mem.startsWith(u8, cpu_line.?, "cpu MHz")) {
                    if (std.mem.indexOf(u8, cpu_line.?, ": ")) |colon_idx| {
                        const mhz_str = cpu_line.?[colon_idx + 2..];
                        const mhz = try std.fmt.parseFloat(f64, mhz_str);
                        metrics.frequency = @as(u32, @intFromFloat(mhz + 0.5));
                        break;
                    }
                }
            }
        }
        
        return metrics;
    }

    fn getRamMetrics(self: *Self) !types.RamMetrics {
        _ = self;
        var metrics = types.RamMetrics{ .total = 0, .used = 0, .percentage = 0.0 };
        
        if (std.Target.current.os.tag == .windows) {
            // Windows 平台使用模拟值
            metrics.total = 8192; // MB
            metrics.used = 3200;
            metrics.percentage = 39.1;
        } else {
            // Linux 平台，读取 /proc/meminfo
            const file = try std.fs.openFileAbsolute("/proc/meminfo", .{});
            defer file.close();
            
            var buf_reader = std.io.bufferedReader(file.reader());
            var in_stream = buf_reader.reader();
            
            var line_buf: [256]u8 = undefined;
            
            while (true) {
                const line = try in_stream.readUntilDelimiterOrEof(&line_buf, '\n');
                if (line == null) break;
                
                if (std.mem.startsWith(u8, line.?, "MemTotal:")) {
                    if (std.mem.indexOf(u8, line.?, ": ")) |colon_idx| {
                        var fields = std.mem.tokenize(u8, line.?[colon_idx + 2..]);
                        if (fields.next()) |val| {
                            const total_kb = try std.fmt.parseInt(u64, val, 10);
                            metrics.total = @as(u64, total_kb / 1024); // 转换为 MB
                        }
                    }
                } else if (std.mem.startsWith(u8, line.?, "MemAvailable:")) {
                    if (std.mem.indexOf(u8, line.?, ": ")) |colon_idx| {
                        var fields = std.mem.tokenize(u8, line.?[colon_idx + 2..]);
                        if (fields.next()) |val| {
                            const available_kb = try std.fmt.parseInt(u64, val, 10);
                            const available_mb = @as(u64, available_kb / 1024);
                            metrics.used = metrics.total - available_mb;
                        }
                    }
                }
            }
            
            if (metrics.total > 0) {
                metrics.percentage = @as(f64, @floatFromInt(metrics.used)) / @as(f64, @floatFromInt(metrics.total)) * 100.0;
            }
        }
        
        return metrics;
    }

    fn getDiskMetrics(self: *Self) !types.DiskMetrics {
        _ = self;
        var metrics = types.DiskMetrics{ .total = 0, .used = 0, .percentage = 0.0 };
        
        // 定义存储目录（这里使用默认值，实际应从配置中获取）
        const storage_dir = "/";
        
        if (std.Target.current.os.tag == .windows) {
            // Windows 平台使用模拟值
            metrics.total = 128; // GB
            metrics.used = 45;
            metrics.percentage = 35.2;
        } else {
            // Linux 平台，使用 std.fs.Dir.stat 或 df 命令
            // 这里使用 df 命令获取存储目录所在分区的信息
            var process = std.process.Child.init(
                &[_][]const u8{"df", "-BG", storage_dir},
                self.allocator
            );
            
            var stdout_buffer = std.ArrayList(u8).init(self.allocator);
            defer stdout_buffer.deinit();
            
            process.stdout_behavior = .Pipe;
            process.stderr_behavior = .Ignore;
            
            try process.spawn();
            
            const stdout = process.stdout.?.reader();
            try stdout_buffer.reader().readAll(stdout);
            
            const result = try process.wait();
            if (result != .Exited or result.Exited != 0) {
                // 如果 df 命令失败，使用默认值
                metrics.total = 100; // GB
                metrics.used = 30;
                metrics.percentage = 30.0;
            } else {
                const output = stdout_buffer.items;
                var lines = std.mem.tokenize(u8, output, "\n");
                
                // 跳过标题行
                _ = lines.next();
                
                if (lines.next()) |line| {
                    var fields = std.mem.tokenize(u8, line);
                    
                    // 跳过文件系统和挂载点字段
                    _ = fields.next();
                    
                    // 读取总大小
                    if (fields.next()) |total_str| {
                        if (std.mem.endsWith(u8, total_str, "G")) {
                            const total_gb_str = total_str[0 .. total_str.len - 1];
                            metrics.total = try std.fmt.parseInt(u64, total_gb_str, 10);
                        }
                    }
                    
                    // 读取已用大小
                    if (fields.next()) |used_str| {
                        if (std.mem.endsWith(u8, used_str, "G")) {
                            const used_gb_str = used_str[0 .. used_str.len - 1];
                            metrics.used = try std.fmt.parseInt(u64, used_gb_str, 10);
                        }
                    }
                    
                    // 计算百分比
                    if (metrics.total > 0) {
                        metrics.percentage = @as(f64, @floatFromInt(metrics.used)) / @as(f64, @floatFromInt(metrics.total)) * 100.0;
                    }
                }
            }
        }
        
        return metrics;
    }

    /// 检查 RDP 连接状态
    pub fn getRdpStatus(self: *Self) !bool {
        _ = self;
        // TODO: 实现 RDP 状态检查
        return false;
    }
};
