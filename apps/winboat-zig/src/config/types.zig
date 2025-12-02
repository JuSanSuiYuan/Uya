// WinBoat-Zig 配置类型定义
// 许可证: MulanPSL-2.0

const std = @import("std");

/// 容器运行时类型
pub const ContainerRuntime = enum {
    qemu_kvm,
    docker,
    podman,
};

/// 容器状态
pub const ContainerStatus = enum {
    exited,
    running,
    paused,
    restarting,
    removing,
    unknown,
};

/// RDP 配置
pub const RdpConfig = struct {
    username: []const u8,
    password: []const u8,
    port: u16,
    scale: u8,
    scale_desktop: u8,
    multi_monitor: u8,
    smartcard_enabled: bool,
    sound_enabled: bool,
    clipboard_enabled: bool,
};

/// 虚拟机规格
pub const VmSpecs = struct {
    cpu_cores: u8,
    memory_mb: u32,
    disk_size_gb: u32,
};

/// WinBoat 主配置
pub const WinboatConfig = struct {
    container_runtime: ContainerRuntime,
    vm_specs: VmSpecs,
    rdp: RdpConfig,
    install_dir: []const u8,
    storage_dir: []const u8,
    experimental_features: bool,
    rdp_monitoring_enabled: bool,

    pub fn default(allocator: std.mem.Allocator) !WinboatConfig {
        return WinboatConfig{
            .container_runtime = .qemu_kvm,
            .vm_specs = .{
                .cpu_cores = 4,
                .memory_mb = 4096,
                .disk_size_gb = 64,
            },
            .rdp = .{
                .username = try allocator.dupe(u8, "winboat"),
                .password = try allocator.dupe(u8, "winboat"),
                .port = 3389,
                .scale = 100,
                .scale_desktop = 100,
                .multi_monitor = 0,
                .smartcard_enabled = false,
                .sound_enabled = true,
                .clipboard_enabled = true,
            },
            .install_dir = try allocator.dupe(u8, "/opt/uya/winboat"),
            .storage_dir = try allocator.dupe(u8, "/var/lib/uya/winboat"),
            .experimental_features = false,
            .rdp_monitoring_enabled = true,
        };
    }

    pub fn deinit(self: *WinboatConfig, allocator: std.mem.Allocator) void {
        allocator.free(self.rdp.username);
        allocator.free(self.rdp.password);
        allocator.free(self.install_dir);
        allocator.free(self.storage_dir);
    }
};

/// 应用信息
pub const AppInfo = struct {
    name: []const u8,
    path: []const u8,
    args: []const u8,
    icon: []const u8,
    source: AppSource,
    usage: u64,
};

/// 应用来源
pub const AppSource = enum {
    internal,
    custom,
    discovered,
};

/// 系统指标
pub const Metrics = struct {
    cpu: CpuMetrics,
    ram: RamMetrics,
    disk: DiskMetrics,
};

pub const CpuMetrics = struct {
    usage: f64, // 0-100
    frequency: u64, // MHz
};

pub const RamMetrics = struct {
    used: u64, // MB
    total: u64, // MB
    percentage: f64,
};

pub const DiskMetrics = struct {
    used: u64, // MB
    total: u64, // MB
    percentage: f64,
};
