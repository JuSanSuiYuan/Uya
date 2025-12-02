// WinBoat-Zig Guest Server
// 许可证: MulanPSL-2.0

const std = @import("std");
const types = @import("../config/types.zig");

pub const GuestServer = struct {
    allocator: std.mem.Allocator,
    port: u16,
    running: bool,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, port: u16) Self {
        return Self{
            .allocator = allocator,
            .port = port,
            .running = false,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// 启动 Guest Server
    pub fn start(self: *Self) !void {
        std.debug.print("启动 Guest Server，监听端口: {d}\n", .{self.port});
        
        // TODO: 实现 HTTP 服务器
        // 使用 Uya 的 IPC/Socket 机制
        
        self.running = true;
    }

    /// 停止 Guest Server
    pub fn stop(self: *Self) !void {
        std.debug.print("停止 Guest Server\n", .{});
        self.running = false;
    }

    /// 获取健康状态
    pub fn getHealth(self: *Self) bool {
        return self.running;
    }

    /// 获取系统指标
    pub fn getMetrics(self: *Self) !types.Metrics {
        const cpu_metrics = try self.getCpuMetrics();
        const ram_metrics = try self.getRamMetrics();
        const disk_metrics = try self.getDiskMetrics();

        return types.Metrics{
            .cpu = cpu_metrics,
            .ram = ram_metrics,
            .disk = disk_metrics,
        };
    }

    fn getCpuMetrics(self: *Self) !types.CpuMetrics {
        _ = self;
        // TODO: 实现 CPU 指标收集
        return types.CpuMetrics{
            .usage = 50.0,
            .frequency = 2400,
        };
    }

    fn getRamMetrics(self: *Self) !types.RamMetrics {
        _ = self;
        // TODO: 实现内存指标收集
        const used: u64 = 2048;
        const total: u64 = 4096;
        return types.RamMetrics{
            .used = used,
            .total = total,
            .percentage = @as(f64, @floatFromInt(used)) / @as(f64, @floatFromInt(total)) * 100.0,
        };
    }

    fn getDiskMetrics(self: *Self) !types.DiskMetrics {
        _ = self;
        // TODO: 实现磁盘指标收集
        const used: u64 = 32768;
        const total: u64 = 65536;
        return types.DiskMetrics{
            .used = used,
            .total = total,
            .percentage = @as(f64, @floatFromInt(used)) / @as(f64, @floatFromInt(total)) * 100.0,
        };
    }

    /// 检查 RDP 连接状态
    pub fn getRdpStatus(self: *Self) !bool {
        _ = self;
        // TODO: 实现 RDP 状态检查
        return false;
    }
};
