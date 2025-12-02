const std = @import("std");
const graphics = @import("drv_graphics");
const vesa = @import("drv_vesa");
const input = @import("drv_input");
const vfs = @import("fs_vfs");

pub const DriverType = enum {
    Default,
    VESA,
};

pub const DriverManager = struct {
    initialized: bool,
    graphics_driver_status: bool,
    graphics_driver_type: DriverType,
    input_driver_status: bool,

    pub fn init(self: *DriverManager) bool {
        self.initialized = false;
        self.graphics_driver_status = false;
        self.graphics_driver_type = .Default;
        self.input_driver_status = false;

        var success = true;

        // 首先尝试初始化VESA显卡驱动
        if (vesa.init()) {
            self.graphics_driver_status = true;
            self.graphics_driver_type = .VESA;
            _ = vfs.UyaFS.addFile("/tmp/driver_status", "VESA graphics driver initialized successfully") catch {};
        } else {
            // 如果VESA驱动初始化失败，回退到默认显卡驱动
            if (!graphics.init()) {
                success = false;
                self.graphics_driver_status = false;
                _ = vfs.UyaFS.addFile("/tmp/driver_errors", "Failed to initialize graphics driver") catch {};
            } else {
                self.graphics_driver_status = true;
                self.graphics_driver_type = .Default;
            }
        }

        // 初始化输入驱动
        if (!input.init()) {
            success = false;
            self.input_driver_status = false;
            _ = vfs.UyaFS.addFile("/tmp/driver_errors", "Failed to initialize input driver") catch {};
        } else {
            self.input_driver_status = true;
        }

        // 记录初始化状态
        if (success) {
            self.initialized = true;
            _ = vfs.UyaFS.addFile("/tmp/driver_status", "All drivers initialized successfully") catch {};
        }

        return success;
    }

    pub fn deinit(self: *DriverManager) void {
        // 反初始化所有驱动
        input.deinit();

        // 根据驱动类型反初始化图形驱动
        switch (self.graphics_driver_type) {
            .VESA => vesa.deinit(),
            .Default => graphics.deinit(),
        }

        _ = vfs.UyaFS.addFile("/tmp/driver_status", "All drivers deinitialized") catch {};
        self.initialized = false;
    }

    pub fn getStatus(self: *DriverManager) []const u8 {
        // 检查所有驱动状态
        var gpu_ok = false;
        var driver_type_str: []const u8 = "None";

        switch (self.graphics_driver_type) {
            .VESA => {
                gpu_ok = vesa.getGpu() != null;
                driver_type_str = "VESA";
            },
            .Default => {
                gpu_ok = graphics.getGpu() != null;
                driver_type_str = "Default";
            },
        }

        const input_ok = input.getInput() != null;

        if (gpu_ok and input_ok) {
            return try std.fmt.allocPrint(std.heap.page_allocator, "All drivers are working properly (Graphics: {s})".*, .{driver_type_str}) catch "Status check failed";
        } else if (gpu_ok) {
            return try std.fmt.allocPrint(std.heap.page_allocator, "Graphics driver working ({s}), Input driver not working".*, .{driver_type_str}) catch "Status check failed";
        } else if (input_ok) {
            return try std.fmt.allocPrint(std.heap.page_allocator, "Input driver working, Graphics driver not working ({s})".*, .{driver_type_str}) catch "Status check failed";
        } else {
            return "Both drivers are not working";
        }
    }

    pub fn testDrivers(self: *DriverManager) ![]const u8 {
        // 测试驱动功能
        const allocator = std.heap.page_allocator;
        var results = std.ArrayList(u8).init(allocator);
        defer results.deinit();

        // 测试显卡驱动
        switch (self.graphics_driver_type) {
            .VESA => {
                if (vesa.getGpu()) |gpu| {
                    // 使用VESA驱动绘制
                    const rect_width: u32 = 100;
                    const rect_height: u32 = 100;
                    const start_x: u32 = (gpu.width - rect_width) / 2;
                    const start_y: u32 = (gpu.height - rect_height) / 2;

                    var y: u32 = start_y;
                    while (y < start_y + rect_height) : (y += 1) {
                        var x: u32 = start_x;
                        while (x < start_x + rect_width) : (x += 1) {
                            const r = @as(u8, @intCast(x - start_x));
                            const g = @as(u8, @intCast(y - start_y));
                            const b = 128;
                            _ = gpu.setPixel(x, y, r, g, b, 255);
                        }
                    }

                    gpu.render();
                    try results.appendSlice("VESA graphics test passed\n");
                } else {
                    try results.appendSlice("VESA graphics test failed: no GPU available\n");
                }
            },
            .Default => {
                if (graphics.getGpu()) |gpu| {
                    // 使用默认驱动绘制
                    const rect_width: u32 = 100;
                    const rect_height: u32 = 100;
                    const start_x: u32 = (gpu.width - rect_width) / 2;
                    const start_y: u32 = (gpu.height - rect_height) / 2;

                    var y: u32 = start_y;
                    while (y < start_y + rect_height) : (y += 1) {
                        var x: u32 = start_x;
                        while (x < start_x + rect_width) : (x += 1) {
                            const r = @as(u8, @intCast(x - start_x));
                            const g = @as(u8, @intCast(y - start_y));
                            const b = 128;
                            _ = gpu.setPixel(x, y, r, g, b, 255);
                        }
                    }

                    gpu.render();
                    try results.appendSlice("Default graphics test passed\n");
                } else {
                    try results.appendSlice("Default graphics test failed: no GPU available\n");
                }
            },
        }

        // 测试输入驱动
        if (input.getInput()) |in| {
            // 模拟一些输入事件
            try input.simulateKeyEvent(65, true); // A key down
            try input.simulateMouseEvent(100, 100, 10, 10, 1); // Mouse click

            const events_count = in.getEventsCount();
            try std.fmt.format(results.writer(), "Input test passed: {} events in queue\n", .{events_count});
        } else {
            try results.appendSlice("Input test failed: no input device available\n");
        }

        return try results.toOwnedSlice();
    }
};

// 全局驱动管理器实例
var driver_manager: DriverManager = DriverManager{
    .initialized = false,
    .graphics_driver_status = false,
    .graphics_driver_type = .Default,
    .input_driver_status = false,
};

pub fn initAllDrivers() bool {
    return driver_manager.init();
}

pub fn deinitAllDrivers() void {
    driver_manager.deinit();
}

pub fn getDriversStatus() []const u8 {
    return driver_manager.getStatus();
}

pub fn runDriverTests() ![]const u8 {
    return driver_manager.testDrivers();
}

pub fn getCurrentGraphicsDriverType() DriverType {
    return driver_manager.graphics_driver_type;
}
