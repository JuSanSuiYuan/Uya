// iso_builder.zig - ISO镜像生成模块
// 木兰开源许可证 Mulan PSL 2.0

const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const process = std.process;
const Build = std.Build;

pub const IsoBuilder = struct {
    b: *Build,
    allocator: mem.Allocator,
    iso_path: []const u8,
    kernel_path: []const u8,
    limine_dir: []const u8,
    iso_root_dir: []const u8,
    
    pub fn init(
        b: *Build,
        allocator: mem.Allocator,
        iso_path: []const u8,
        kernel_path: []const u8,
        limine_dir: []const u8,
        iso_root_dir: []const u8,
    ) IsoBuilder {
        return .{
            .b = b,
            .allocator = allocator,
            .iso_path = iso_path,
            .kernel_path = kernel_path,
            .limine_dir = limine_dir,
            .iso_root_dir = iso_root_dir,
        };
    }
    
    // 准备ISO根目录
    pub fn prepareIsoRoot(self: *IsoBuilder) !void {
        // 清理或创建ISO根目录
        if (fs.pathExistsAbsolute(self.iso_root_dir)) {
            try fs.deleteTreeAbsolute(self.iso_root_dir);
        }
        try fs.makeDirAbsolute(self.iso_root_dir);
        
        // 创建EFI目录结构
        const efi_boot_dir = try fs.path.join(self.allocator, &[3][]const u8{ 
            self.iso_root_dir, "EFI", "BOOT" 
        });
        defer self.allocator.free(efi_boot_dir);
        
        try fs.makeDirAbsolute(efi_boot_dir);
        self.b.installDirectory(.{
            .source_dir = self.iso_root_dir,
            .install_dir = .{ .custom = self.iso_root_dir },
            .install_subdir = ".",
        });
    }
    
    // 复制必要的文件到ISO根目录
    pub fn copyRequiredFiles(self: *IsoBuilder) !void {
        // 复制内核文件 - 使用Uya内核文件名
        const kernel_dest = try fs.path.join(self.allocator, &[2][]const u8{ 
            self.iso_root_dir, "uyakernel" 
        });
        defer self.allocator.free(kernel_dest);
        
        if (fs.pathExistsAbsolute(self.kernel_path)) {
            try fs.copyFileAbsolute(self.kernel_path, kernel_dest, .{});
            self.b.step(.{ .id = .custom, .name = "copy-kernel" }).emit(.info, "已复制内核文件到ISO根目录");
        } else {
            // 尝试查找替代内核位置
            const alt_kernel_path = try fs.path.join(self.allocator, &[2][]const u8{ 
                self.b.build_root, "uyakernel" 
            });
            defer self.allocator.free(alt_kernel_path);
            
            if (fs.pathExistsAbsolute(alt_kernel_path)) {
                try fs.copyFileAbsolute(alt_kernel_path, kernel_dest, .{});
                self.b.step(.{ .id = .custom, .name = "copy-alt-kernel" }).emit(.info, "已从替代位置复制内核文件");
            } else {
                // 创建空文件避免构建失败
                try fs.createFileAbsolute(kernel_dest, .{});
                self.b.step(.{ .id = .custom, .name = "warn-kernel" }).emit(.warn, "警告：找不到内核文件，创建空文件以继续");
            }
        }
        
        // 复制Limine配置文件
        const limine_cfg_src = try fs.path.join(self.allocator, &[2][]const u8{ 
            self.limine_dir, "limine.cfg" 
        });
        defer self.allocator.free(limine_cfg_src);
        
        const limine_cfg_dest = try fs.path.join(self.allocator, &[2][]const u8{ 
            self.iso_root_dir, "limine.cfg" 
        });
        defer self.allocator.free(limine_cfg_dest);
        
        if (fs.pathExistsAbsolute(limine_cfg_src)) {
            try fs.copyFileAbsolute(limine_cfg_src, limine_cfg_dest, .{});
        } else {
            // 创建默认配置文件 - 使用Uya默认配置
            try self.createDefaultLimineConfig(limine_cfg_dest);
        }
        
        // 复制传统BIOS引导文件
        const limine_sys_src = try fs.path.join(self.allocator, &[2][]const u8{ 
            self.limine_dir, "limine.sys" 
        });
        defer self.allocator.free(limine_sys_src);
        
        const limine_sys_dest = try fs.path.join(self.allocator, &[2][]const u8{ 
            self.iso_root_dir, "limine.sys" 
        });
        defer self.allocator.free(limine_sys_dest);
        
        if (fs.pathExistsAbsolute(limine_sys_src)) {
            try fs.copyFileAbsolute(limine_sys_src, limine_sys_dest, .{});
        } else {
            // 创建空文件避免构建失败
            try fs.createFileAbsolute(limine_sys_dest, .{});
            self.b.step(.{ .id = .custom, .name = "warn-limine-sys" }).emit(.warn, "警告：找不到Limine传统引导文件");
        }
        
        // 复制UEFI引导文件
        const limine_efi_src = try fs.path.join(self.allocator, &[2][]const u8{ 
            self.limine_dir, "limine-uefi-cd.bin" 
        });
        defer self.allocator.free(limine_efi_src);
        
        const limine_efi_dest = try fs.path.join(self.allocator, &[3][]const u8{ 
            self.iso_root_dir, "EFI", "BOOT", "BOOTX64.EFI" 
        });
        defer self.allocator.free(limine_efi_dest);
        
        if (fs.pathExistsAbsolute(limine_efi_src)) {
            try fs.copyFileAbsolute(limine_efi_src, limine_efi_dest, .{});
            self.b.step(.{ .id = .custom, .name = "copy-uefi" }).emit(.info, "已复制UEFI引导文件");
        } else {
            // 创建空文件避免构建失败
            try fs.createFileAbsolute(limine_efi_dest, .{});
            self.b.step(.{ .id = .custom, .name = "warn-uefi" }).emit(.warn, "警告：找不到UEFI引导文件");
        }
    }
    
    // 创建默认的Limine配置文件 - 适配Uya
    fn createDefaultLimineConfig(self: *IsoBuilder, config_path: []const u8) !void {
        const config_content = \
        "# Limine配置文件 - Uya操作系统\n"
        "# 木兰开源许可证 Mulan PSL 2.0\n\n"
        "# 启动菜单超时时间（秒）\n"
        "TIMEOUT=0\n\n"
        "# 默认启动项\n"
        "DEFAULT_ENTRY=Uya\n\n"
        "# 启动项定义\n"
        "ENTRY=Uya\n"
        "KERNEL_PATH=boot:///uyakernel\n"
        "KERNEL_CMDLINE=\n";
        
        try fs.writeFileAbsolute(config_path, config_content);
    }
    
    // 生成ISO镜像
    pub fn buildIso(self: *IsoBuilder) !*Build.Step {
        const step = self.b.allocator.create(Build.Step) catch unreachable;
        step.* = Build.Step.init(.{ 
            .id = .custom,
            .name = "build-iso",
            .owner = self.b,
            .makeFn = makeIsoStep,
        });
        
        // 存储必要的上下文
        const context = try self.allocator.create(Context);
        context.* = .{
            .builder = self,
        };
        step.user_data = context;
        
        return step;
    }
    
    const Context = struct {
        builder: *IsoBuilder,
    };
    
    fn makeIsoStep(step: *Build.Step) !void {
        const context = @as(*Context, @ptrCast(@alignCast(step.user_data)));
        const self = context.builder;
        
        // 准备ISO根目录
        try self.prepareIsoRoot();
        
        // 复制必要文件
        try self.copyRequiredFiles();
        
        // 查找并使用合适的ISO创建工具
        try self.findAndUseIsoTool();
    }
    
    // 查找并使用合适的ISO创建工具
    fn findAndUseIsoTool(self: *IsoBuilder) !void {
        const tools = [_]struct { name: []const u8, args: []const []const u8 }{ 
            .{ 
                .name = "xorriso",
                .args = &[_][]const u8{ 
                    "-as", "mkisofs", 
                    "-b", "limine.sys", 
                    "-no-emul-boot", 
                    "-boot-load-size", "4", 
                    "-boot-info-table",
                    "--efi-boot", "EFI/BOOT/BOOTX64.EFI",
                    "-efi-boot-part",
                    "--efi-boot-image",
                    "--protective-msdos-label",
                    self.iso_root_dir,
                    "-o", self.iso_path
                }
            },
            .{ 
                .name = "genisoimage",
                .args = &[_][]const u8{ 
                    "-b", "limine.sys", 
                    "-no-emul-boot", 
                    "-boot-load-size", "4", 
                    "-boot-info-table",
                    "-eltorito-alt-boot",
                    "-e", "EFI/BOOT/BOOTX64.EFI",
                    "-no-emul-boot",
                    "-o", self.iso_path,
                    self.iso_root_dir
                }
            },
            .{ 
                .name = "mkisofs",
                .args = &[_][]const u8{ 
                    "-b", "limine.sys", 
                    "-no-emul-boot", 
                    "-boot-load-size", "4", 
                    "-boot-info-table",
                    "-eltorito-alt-boot",
                    "-e", "EFI/BOOT/BOOTX64.EFI",
                    "-no-emul-boot",
                    "-o", self.iso_path,
                    self.iso_root_dir
                }
            },
        };
        
        // 尝试在Windows上查找这些工具
        for (tools) |tool| {
            if (try self.toolExists(tool.name)) {
                self.b.step(.{ .id = .custom, .name = "iso-tool" }).emit(.info, "使用工具 " ++ tool.name ++ " 创建ISO镜像");
                
                // 创建命令步骤
                const cmd_step = self.b.addSystemCommand(tool.args);
                try cmd_step.step.make();
                
                // 验证ISO是否创建成功
                if (fs.pathExistsAbsolute(self.iso_path)) {
                    self.b.step(.{ .id = .custom, .name = "iso-success" }).emit(.info, "ISO镜像创建成功: " ++ self.iso_path);
                    return;
                } else {
                    self.b.step(.{ .id = .custom, .name = "iso-fail" }).emit(.err, "错误：ISO镜像创建失败");
                    continue;
                }
            }
        }
        
        // 所有工具都失败了，给出提示
        self.b.step(.{ .id = .custom, .name = "no-tools" }).emit(.warn, "警告：找不到ISO创建工具（xorriso, genisoimage, mkisofs）");
        self.b.step(.{ .id = .custom, .name = "prep-done" }).emit(.info, "ISO根目录内容位于: " ++ self.iso_root_dir);
        self.b.step(.{ .id = .custom, .name = "manual-inst" }).emit(.info, "请手动安装ISO创建工具并创建ISO镜像");
    }
    
    // 检查工具是否存在
    fn toolExists(self: *IsoBuilder, tool_name: []const u8) !bool {
        // 在Windows上检查工具是否在PATH中
        const result = try process.execveZ(self.allocator, &[_][]const u8{ "where.exe", tool_name }, &.{});
        defer self.allocator.free(result.stderr);
        defer self.allocator.free(result.stdout);
        
        return result.term.Exited == 0;
    }
};

// 为Build添加ISO构建功能的扩展
pub fn addIsoBuildStep(
    b: *Build,
    kernel_artifact: *Build.Step.Compile,
    limine_dir: []const u8,
    dist_dir: []const u8,
) *Build.Step {
    const allocator = b.allocator;
    
    // 设置默认路径 - 使用Uya的默认文件名
    const iso_path = try allocator.dupe(u8, try fs.path.join(allocator, &[2][]const u8{ dist_dir, "uya.iso" }));
    const kernel_path = try allocator.dupe(u8, try fs.path.join(allocator, &[2][]const u8{ 
        kernel_artifact.getOutputSource().getPath(b) orelse try fs.path.join(allocator, &[2][]const u8{ 
            b.install_path, "bin", kernel_artifact.name 
        }), 
    }));
    const iso_root_dir = try allocator.dupe(u8, try fs.path.join(allocator, &[2][]const u8{ dist_dir, "iso_root" }));
    
    // 创建ISO构建器
    const builder = try allocator.create(IsoBuilder);
    builder.* = IsoBuilder.init(b, allocator, iso_path, kernel_path, limine_dir, iso_root_dir);
    
    // 创建ISO构建步骤
    const iso_step = try builder.buildIso();
    
    // 确保内核构建在ISO构建之前完成
    iso_step.dependOn(&kernel_artifact.step);
    
    return iso_step;
}