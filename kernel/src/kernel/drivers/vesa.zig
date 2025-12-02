const std = @import("std");
const vfs = @import("fs/vfs.zig");

// VESA BIOS扩展相关常量和结构体
pub const VESA_MODE_ATTR_SUPPORTED = 0x0001;
pub const VESA_MODE_ATTR_GRAPHICS = 0x0002;
pub const VESA_MODE_ATTR_COLOR = 0x0004;
pub const VESA_MODE_ATTR_GUI = 0x0008;
pub const VESA_MODE_ATTR_LFB = 0x4000;

// VESA VBE信息结构体
export const VbeInfoBlock = extern struct {
    vbe_signature: [4]u8,         // 签名，必须是"VESA"
    vbe_version: u16,             // VBE版本号
    oem_string_ptr: u32,          // OEM字符串指针
    capabilities: u32,            // 显卡能力标志
    video_mode_ptr: u32,          // 视频模式列表指针
    total_memory: u16,            // 总内存大小(以64KB为单位)
    // 其他字段略去
};

// VESA模式信息结构体
export const VesaModeInfo = extern struct {
    mode_attributes: u16,         // 模式属性
    win_a_attributes: u8,         // 窗口A属性
    win_b_attributes: u8,         // 窗口B属性
    win_granularity: u16,         // 窗口粒度
    win_size: u16,                // 窗口大小
    win_a_segment: u16,           // 窗口A段地址
    win_b_segment: u16,           // 窗口B段地址
    win_func_ptr: u32,            // 窗口功能指针
    bytes_per_scan_line: u16,     // 每行字节数
    x_resolution: u16,            // X分辨率
    y_resolution: u16,            // Y分辨率
    x_charsize: u8,               // X字符大小
    y_charsize: u8,               // Y字符大小
    number_of_planes: u8,         // 位面数
    bits_per_pixel: u8,           // 每像素位数
    number_of_banks: u8,          // 存储库数量
    memory_model: u8,             // 内存模型
    bank_size: u8,                // 存储库大小
    number_of_image_pages: u8,    // 图像页数
    reserved0: u8,                // 保留
    red_mask_size: u8,            // 红色掩码大小
    red_field_position: u8,       // 红色字段位置
    green_mask_size: u8,          // 绿色掩码大小
    green_field_position: u8,     // 绿色字段位置
    blue_mask_size: u8,           // 蓝色掩码大小
    blue_field_position: u8,      // 蓝色字段位置
    reserved_mask_size: u8,       // 保留掩码大小
    reserved_field_position: u8,  // 保留字段位置
    direct_color_mode_info: u8,   // 直接颜色模式信息
    phys_base_ptr: u32,           // 线性帧缓冲区物理地址
    reserved1: u32,               // 保留
    reserved2: u16,               // 保留
    // 其他字段略去
};

// VESA驱动结构体，实现GraphicsDriver接口
export const VesaDriver = struct {
    width: u32,
    height: u32,
    bpp: u8,
    framebuffer: [*]u8,
    bytes_per_line: u16,
    initialized: bool,
    mode_info: VesaModeInfo,

    // 计算像素地址的辅助函数
    fn getPixelAddress(self: *VesaDriver, x: u32, y: u32) ?[*]u8 {
        if (!self.initialized || x >= self.width || y >= self.height) return null;
        
        // 使用bytes_per_line计算更准确的行偏移
        const row_offset = y * self.bytes_per_line;
        const pixel_offset = x * @divExact(@as(u32, self.bpp), 8);
        return self.framebuffer + row_offset + pixel_offset;
    }

    // 设置像素颜色
    pub fn setPixel(self: *VesaDriver, x: u32, y: u32, r: u8, g: u8, b: u8, a: u8) bool {
        const pixel_address = self.getPixelAddress(x, y) orelse return false;
        
        switch (self.bpp) {
            32 => {
                @as(*u32, @ptrCast(pixel_address)).* = 
                    (@as(u32, b)) | 
                    (@as(u32, g) << 8) | 
                    (@as(u32, r) << 16) | 
                    (@as(u32, a) << 24);
            },
            24 => {
                // 24位颜色: BGR顺序
                pixel_address[0] = b;
                pixel_address[1] = g;
                pixel_address[2] = r;
            },
            16 => {
                // 5-6-5 RGB格式
                const color: u16 = (@as(u16, r & 0xF8) << 8) | 
                                 (@as(u16, g & 0xFC) << 3) | 
                                 (b >> 3);
                @as(*u16, @ptrCast(pixel_address)).* = color;
            },
            else => {
                return false; // 不支持的颜色深度
            },
        }
        
        return true;
    }

    // 批量设置一行像素的高效实现
    pub fn fillHorizontalLine(self: *VesaDriver, x_start: u32, x_end: u32, y: u32, r: u8, g: u8, b: u8, a: u8) bool {
        if (!self.initialized || y >= self.height) return false;
        
        // 调整坐标范围
        const start_x = if (x_start >= self.width) self.width - 1 else x_start;
        const end_x = if (x_end >= self.width) self.width - 1 else x_end;
        
        if (start_x > end_x) return false;
        
        const row_offset = y * self.bytes_per_line;
        const pixel_size = @divExact(@as(u32, self.bpp), 8);
        
        switch (self.bpp) {
            32 => {
                const pixel_value: u32 = 
                    (@as(u32, b)) | 
                    (@as(u32, g) << 8) | 
                    (@as(u32, r) << 16) | 
                    (@as(u32, a) << 24);
                
                var x = start_x;
                while (x <= end_x) : (x += 1) {
                    const pixel_offset = x * pixel_size;
                    @as(*u32, @ptrCast(self.framebuffer + row_offset + pixel_offset)).* = pixel_value;
                }
            },
            24 => {
                var x = start_x;
                while (x <= end_x) : (x += 1) {
                    const pixel_offset = x * pixel_size;
                    const pixel_address = self.framebuffer + row_offset + pixel_offset;
                    pixel_address[0] = b;
                    pixel_address[1] = g;
                    pixel_address[2] = r;
                }
            },
            16 => {
                const color: u16 = (@as(u16, r & 0xF8) << 8) | 
                                 (@as(u16, g & 0xFC) << 3) | 
                                 (b >> 3);
                
                var x = start_x;
                while (x <= end_x) : (x += 1) {
                    const pixel_offset = x * pixel_size;
                    @as(*u16, @ptrCast(self.framebuffer + row_offset + pixel_offset)).* = color;
                }
            },
            else => {
                return false;
            },
        }
        
        return true;
    }

    // 清屏函数，使用更高效的行填充方式
    pub fn clear(self: *VesaDriver, r: u8, g: u8, b: u8, a: u8) bool {
        if (!self.initialized) return false;
        
        // 使用fillHorizontalLine逐行填充，利用CPU缓存局部性
        var y: u32 = 0;
        while (y < self.height) : (y += 1) {
            _ = self.fillHorizontalLine(0, self.width - 1, y, r, g, b, a);
        }
        
        return true;
    }

    // 绘制矩形
    pub fn drawRectangle(self: *VesaDriver, x: u32, y: u32, width: u32, height: u32, r: u8, g: u8, b: u8, a: u8) bool {
        if (!self.initialized || width == 0 || height == 0) return false;
        
        // 调整坐标范围
        const x_end = if (x + width > self.width) self.width - 1 else x + width - 1;
        const y_end = if (y + height > self.height) self.height - 1 else y + height - 1;
        
        if (x >= self.width || y >= self.height || x_end < x || y_end < y) return false;
        
        // 逐行填充矩形区域
        var current_y = y;
        while (current_y <= y_end) : (current_y += 1) {
            _ = self.fillHorizontalLine(x, x_end, current_y, r, g, b, a);
        }
        
        return true;
    }

    // 渲染函数（对于直接帧缓冲，这可能是一个空操作）
    pub fn render(self: *VesaDriver) bool {
        if (!self.initialized) return false;
        // 直接操作帧缓冲，不需要额外的渲染步骤
        // 可以在这里添加垂直同步等待等功能（如果硬件支持）
        return true;
    }

    // 获取驱动信息
    pub fn getInfo(self: *VesaDriver, buffer: []u8) ![]const u8 {
        return try std.fmt.bufPrint(buffer, "VESA Driver: {d}x{d}@{d}bpp, LFB at 0x{x}", .{
            self.width,
            self.height,
            self.bpp,
            @intFromPtr(self.framebuffer),
        });
    }
};

// 全局VESA驱动实例
var vesa_driver: VesaDriver = .{
    .width = 0,
    .height = 0,
    .bpp = 0,
    .framebuffer = undefined,
    .bytes_per_line = 0,
    .initialized = false,
    .mode_info = undefined,
};

// 获取VESA驱动实例
pub fn getVesaDriver() *VesaDriver {
    return &vesa_driver;
}

// 汇编函数声明，用于调用VESA BIOS中断
extern fn vesaGetVbeInfo(info_block_ptr: *VbeInfoBlock) callconv(.Naked) u16;
extern fn vesaSetVideoMode(mode: u16) callconv(.Naked) u16;
extern fn vesaGetModeInfo(mode: u16, info_ptr: *VesaModeInfo) callconv(.Naked) u16;

// 查找合适的VESA模式（寻找高分辨率、彩色、支持LFB的模式）
fn findBestMode() !u16 {
    // 在实际实现中，这里应该扫描VBE返回的模式列表
    // 并选择最佳模式。这里为了示例，我们直接返回一个常用的模式
    return 0x118; // 1024x768x24bpp
}

// 初始化VESA驱动
pub fn init() bool {
    var vbe_info: VbeInfoBlock = undefined;
    var mode_info: VesaModeInfo = undefined;
    
    // 尝试获取VBE信息
    const vbe_result = vesaGetVbeInfo(&vbe_info);
    if (vbe_result != 0x4F) {
        // 保存错误信息到VFS
        _ = vfs.writeFile("/sys/log/vesa_error", "Failed to get VBE info\n") catch {};
        return false;
    }
    
    // 验证签名
    if (!std.mem.eql(u8, &vbe_info.vbe_signature, "VESA")) {
        _ = vfs.writeFile("/sys/log/vesa_error", "Invalid VESA signature\n") catch {};
        return false;
    }
    
    // 查找并设置最佳模式
    const best_mode = findBestMode() catch |err| {
        const error_msg = try std.fmt.allocPrint(std.heap.page_allocator, "Failed to find best mode: {!}\n", .{err});
        defer std.heap.page_allocator.free(error_msg);
        _ = vfs.writeFile("/sys/log/vesa_error", error_msg) catch {};
        return false;
    };
    
    // 获取模式信息
    const mode_result = vesaGetModeInfo(best_mode, &mode_info);
    if (mode_result != 0x4F) {
        _ = vfs.writeFile("/sys/log/vesa_error", "Failed to get mode info\n") catch {};
        return false;
    }
    
    // 检查模式是否支持LFB
    if ((mode_info.mode_attributes & VESA_MODE_ATTR_LFB) == 0) {
        _ = vfs.writeFile("/sys/log/vesa_error", "Mode doesn't support LFB\n") catch {};
        return false;
    }
    
    // 设置视频模式
    const set_mode_result = vesaSetVideoMode(best_mode | 0x4000); // 0x4000表示使用LFB
    if (set_mode_result != 0x4F) {
        _ = vfs.writeFile("/sys/log/vesa_error", "Failed to set video mode\n") catch {};
        return false;
    }
    
    // 初始化驱动结构
    vesa_driver.width = @intCast(u32, mode_info.x_resolution);
    vesa_driver.height = @intCast(u32, mode_info.y_resolution);
    vesa_driver.bpp = mode_info.bits_per_pixel;
    vesa_driver.framebuffer = @intToPtr([*]u8, mode_info.phys_base_ptr);
    vesa_driver.bytes_per_line = mode_info.bytes_per_scan_line;
    vesa_driver.initialized = true;
    vesa_driver.mode_info = mode_info;
    
    // 清屏为黑色
    _ = vesa_driver.clear(0, 0, 0, 255);
    
    // 保存成功信息到VFS
    const success_msg = try std.fmt.allocPrint(std.heap.page_allocator, 
        "VESA initialized successfully: {d}x{d}@{d}bpp\n", 
        .{vesa_driver.width, vesa_driver.height, vesa_driver.bpp}
    );
    defer std.heap.page_allocator.free(success_msg);
    _ = vfs.writeFile("/sys/log/vesa_info", success_msg) catch {};
    
    return true;
}

// 反初始化VESA驱动
pub fn deinit() void {
    // 反初始化VESA驱动
    vesa_driver.initialized = false;
}

// 获取驱动是否已初始化
pub fn isInitialized() bool {
    return vesa_driver.initialized;
}

// 获取驱动状态
pub fn getStatus() []const u8 {
    if (vesa_driver.initialized) {
        return "VESA driver initialized successfully";
    } else {
        return "VESA driver not initialized";
    }
}
