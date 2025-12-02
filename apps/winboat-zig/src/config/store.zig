// WinBoat-Zig 配置存储
// 许可证: MulanPSL-2.0

const std = @import("std");
const types = @import("types.zig");
const json = std.json;

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

        // 分配缓冲区并读取文件内容
        const file_size = try file.getEndPos();
        const buffer = try self.allocator.alloc(u8, file_size);
        defer self.allocator.free(buffer);
        
        const bytes_read = try file.readAll(buffer);
        
        // 解析 JSON
        var parse_options = std.json.ParseOptions{ .allocator = self.allocator };
        defer parse_options.deinit();
        
        // 首先解析为通用 JSON 结构
        const parsed = try json.parseFromSlice(json.Value, self.allocator, buffer[0..bytes_read], parse_options);
        defer parsed.deinit();
        
        // 尝试从 JSON 中提取配置
        if (parsed.value.object) |obj| {
            // 清理现有配置
            self.config.deinit(self.allocator);
            
            // 创建新配置
            self.config = try self.parseConfigFromJson(obj, self.allocator);
        }
    }

    /// 保存配置到文件
    pub fn save(self: *Self) !void {
        const file = try std.fs.cwd().createFile(self.config_path, .{});
        defer file.close();

        // 序列化配置到 JSON
        const json_str = try self.serializeConfigToJson(self.config, self.allocator);
        defer self.allocator.free(json_str);
        
        try file.writeAll(json_str);
    }

    /// 获取配置引用
    pub fn getConfig(self: *Self) *types.WinboatConfig {
        return &self.config;
    }
    
    /// 从 JSON 对象解析配置
    fn parseConfigFromJson(self: *Self, obj: std.json.ObjectMap, allocator: std.mem.Allocator) !types.WinboatConfig {
        var config = try types.WinboatConfig.default(allocator);
        
        // 解析容器运行时
        if (obj.get("container_runtime")) |runtime_val| {
            if (runtime_val.string) |runtime_str| {
                if (std.mem.eql(u8, runtime_str, "qemu_kvm")) {
                    config.container_runtime = .qemu_kvm;
                } else if (std.mem.eql(u8, runtime_str, "docker")) {
                    config.container_runtime = .docker;
                } else if (std.mem.eql(u8, runtime_str, "podman")) {
                    config.container_runtime = .podman;
                }
            }
        }
        
        // 解析 VM 规格
        if (obj.get("vm_specs")) |specs_val| {
            if (specs_val.object) |specs_obj| {
                // CPU 核心数
                if (specs_obj.get("cpu_cores")) |cpu_val| {
                    if (cpu_val.integer) |cpu_int| {
                        config.vm_specs.cpu_cores = @as(u8, @intCast(cpu_int));
                    }
                }
                // 内存大小
                if (specs_obj.get("memory_mb")) |mem_val| {
                    if (mem_val.integer) |mem_int| {
                        config.vm_specs.memory_mb = @as(u32, @intCast(mem_int));
                    }
                }
                // 磁盘大小
                if (specs_obj.get("disk_size_gb")) |disk_val| {
                    if (disk_val.integer) |disk_int| {
                        config.vm_specs.disk_size_gb = @as(u32, @intCast(disk_int));
                    }
                }
            }
        }
        
        // 解析 RDP 配置
        if (obj.get("rdp")) |rdp_val| {
            if (rdp_val.object) |rdp_obj| {
                if (rdp_obj.get("username")) |user_val| {
                    if (user_val.string) |user_str| {
                        self.allocator.free(config.rdp.username);
                        config.rdp.username = try allocator.dupe(u8, user_str);
                    }
                }
                if (rdp_obj.get("password")) |pass_val| {
                    if (pass_val.string) |pass_str| {
                        self.allocator.free(config.rdp.password);
                        config.rdp.password = try allocator.dupe(u8, pass_str);
                    }
                }
                if (rdp_obj.get("port")) |port_val| {
                    if (port_val.integer) |port_int| {
                        config.rdp.port = @as(u16, @intCast(port_int));
                    }
                }
            }
        }
        
        // 解析目录配置
        if (obj.get("install_dir")) |dir_val| {
            if (dir_val.string) |dir_str| {
                self.allocator.free(config.install_dir);
                config.install_dir = try allocator.dupe(u8, dir_str);
            }
        }
        if (obj.get("storage_dir")) |dir_val| {
            if (dir_val.string) |dir_str| {
                self.allocator.free(config.storage_dir);
                config.storage_dir = try allocator.dupe(u8, dir_str);
            }
        }
        
        // 解析布尔配置
        if (obj.get("experimental_features")) |exp_val| {
            if (exp_val.bool) |exp_bool| {
                config.experimental_features = exp_bool;
            }
        }
        if (obj.get("rdp_monitoring_enabled")) |mon_val| {
            if (mon_val.bool) |mon_bool| {
                config.rdp_monitoring_enabled = mon_bool;
            }
        }
        
        return config;
    }
    
    /// 将配置序列化为 JSON
    fn serializeConfigToJson(self: *Self, config: types.WinboatConfig, allocator: std.mem.Allocator) ![]const u8 {
        var json_obj = std.json.ObjectMap.init(allocator);
        defer json_obj.deinit();
        
        // 序列化容器运行时
        const runtime_str = switch (config.container_runtime) {
            .qemu_kvm => "qemu_kvm",
            .docker => "docker",
            .podman => "podman",
        };
        try json_obj.put("container_runtime", json.Value{ .string = try allocator.dupe(u8, runtime_str) });
        
        // 序列化 VM 规格
        var vm_specs_obj = std.json.ObjectMap.init(allocator);
        try vm_specs_obj.put("cpu_cores", json.Value{ .integer = config.vm_specs.cpu_cores });
        try vm_specs_obj.put("memory_mb", json.Value{ .integer = config.vm_specs.memory_mb });
        try vm_specs_obj.put("disk_size_gb", json.Value{ .integer = config.vm_specs.disk_size_gb });
        try json_obj.put("vm_specs", json.Value{ .object = vm_specs_obj });
        
        // 序列化 RDP 配置
        var rdp_obj = std.json.ObjectMap.init(allocator);
        try rdp_obj.put("username", json.Value{ .string = try allocator.dupe(u8, config.rdp.username) });
        try rdp_obj.put("password", json.Value{ .string = try allocator.dupe(u8, config.rdp.password) });
        try rdp_obj.put("port", json.Value{ .integer = config.rdp.port });
        try rdp_obj.put("scale", json.Value{ .integer = config.rdp.scale });
        try rdp_obj.put("scale_desktop", json.Value{ .integer = config.rdp.scale_desktop });
        try rdp_obj.put("multi_monitor", json.Value{ .integer = config.rdp.multi_monitor });
        try rdp_obj.put("smartcard_enabled", json.Value{ .bool = config.rdp.smartcard_enabled });
        try rdp_obj.put("sound_enabled", json.Value{ .bool = config.rdp.sound_enabled });
        try rdp_obj.put("clipboard_enabled", json.Value{ .bool = config.rdp.clipboard_enabled });
        try json_obj.put("rdp", json.Value{ .object = rdp_obj });
        
        // 序列化目录配置
        try json_obj.put("install_dir", json.Value{ .string = try allocator.dupe(u8, config.install_dir) });
        try json_obj.put("storage_dir", json.Value{ .string = try allocator.dupe(u8, config.storage_dir) });
        
        // 序列化布尔配置
        try json_obj.put("experimental_features", json.Value{ .bool = config.experimental_features });
        try json_obj.put("rdp_monitoring_enabled", json.Value{ .bool = config.rdp_monitoring_enabled });
        
        // 转换为 JSON 字符串
        var json_value = json.Value{ .object = json_obj };
        const json_str = try json.stringifyAlloc(allocator, json_value, .{});
        
        return json_str;
    }
};
