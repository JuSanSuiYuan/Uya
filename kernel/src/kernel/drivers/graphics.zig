const std = @import("std");
const vfs = @import("fs_vfs");

pub const GraphicsDriver = struct {
    width: u32,
    height: u32,
    buffer: []u8,
    
    pub fn init(width: u32, height: u32, allocator: std.mem.Allocator) !*GraphicsDriver {
        const self = try allocator.create(GraphicsDriver);
        self.* = .{
            .width = width,
            .height = height,
            .buffer = try allocator.alloc(u8, width * height * 4), // RGBA8888
        };
        return self;
    }
    
    pub fn deinit(self: *GraphicsDriver, allocator: std.mem.Allocator) void {
        allocator.free(self.buffer);
        allocator.destroy(self);
    }
    
    pub fn setPixel(self: *GraphicsDriver, x: u32, y: u32, r: u8, g: u8, b: u8, a: u8) bool {
        if (x >= self.width or y >= self.height) return false;
        const index = (y * self.width + x) * 4;
        self.buffer[index] = r;
        self.buffer[index + 1] = g;
        self.buffer[index + 2] = b;
        self.buffer[index + 3] = a;
        return true;
    }
    
    pub fn clear(self: *GraphicsDriver, r: u8, g: u8, b: u8, a: u8) void {
        var y: u32 = 0;
        while (y < self.height) : (y += 1) {
            var x: u32 = 0;
            while (x < self.width) : (x += 1) {
                _ = self.setPixel(x, y, r, g, b, a);
            }
        }
    }
    
    pub fn render(self: *GraphicsDriver) void {
        // 这里会实现实际的渲染逻辑
        // 目前只是一个占位符
        _ = vfs.UyaFS.addFile("/tmp/graphics_buffer", self.buffer) catch {};
    }
};

// 默认显卡设备
var default_gpu: ?*GraphicsDriver = null;

pub fn init() bool {
    const allocator = std.heap.page_allocator;
    default_gpu = GraphicsDriver.init(1024, 768, allocator) catch return false;
    if (default_gpu) |gpu| {
        gpu.clear(0, 0, 0, 255); // 清屏为黑色
    }
    return true;
}

pub fn getGpu() ?*GraphicsDriver {
    return default_gpu;
}

pub fn deinit() void {
    if (default_gpu) |gpu| {
        gpu.deinit(std.heap.page_allocator);
        default_gpu = null;
    }
}
