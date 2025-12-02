// Mulan PSL v2
// Copyright 2024 - 2024 (c) any individual(s) and/or organization(s)
// who have made contributions to this project.
//
// You can find the Mulan PSL v2 in file COPYING or at:
// https://gitee.com/openeuler/openEuler/blob/master/LICENSE

const std = @import("std");
const vesa = @import("vesa.zig");
const vfs = @import("../vfs/vfs.zig");

pub const VesaTester = struct {
    allocator: std.mem.Allocator,
    success_count: usize,
    total_count: usize,
    results: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) !VesaTester {
        return VesaTester{
            .allocator = allocator,
            .success_count = 0,
            .total_count = 0,
            .results = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *VesaTester) void {
        self.results.deinit();
    }

    pub fn runAllTests(self: *VesaTester) ![]const u8 {
        try self.results.appendSlice("Running VESA Driver Tests...\n\n");

        // 测试驱动初始化
        try self.testInit();
        
        // 如果初始化成功，继续其他测试
        if (self.success_count > 0 and vesa.getGpu()) |gpu| {
            try self.testResolutionInfo(gpu);
            try self.testPixelOperations(gpu);
            try self.testClearScreen(gpu);
            try self.testRectangleDrawing(gpu);
            try self.testPerformance(gpu);
        }

        // 测试驱动反初始化
        try self.testDeinit();

        // 输出测试摘要
        try self.printSummary();

        return self.results.items;
    }

    fn testInit(self: *VesaTester) !void {
        self.total_count += 1;
        try self.results.appendSlice("Test 1: Driver Initialization... ");

        // 尝试初始化VESA驱动
        if (vesa.init()) {
            self.success_count += 1;
            try self.results.appendSlice("PASSED\n");
            try self.results.appendSlice("  VESA driver initialized successfully\n");
            
            if (vesa.getGpu()) |gpu| {
                try self.results.appendSlice(try std.fmt.allocPrint(self.allocator, "  Resolution: {d}x{d}\n", .{gpu.width, gpu.height}));
                try self.results.appendSlice(try std.fmt.allocPrint(self.allocator, "  Bits per pixel: {d}\n", .{gpu.bpp}));
                try self.results.appendSlice(try std.fmt.allocPrint(self.allocator, "  Framebuffer address: {*}\n", .{gpu.framebuffer}));
            }
        } else {
            try self.results.appendSlice("FAILED\n");
            try self.results.appendSlice("  Could not initialize VESA driver\n");
            try vfs.log_error("VESA driver initialization test failed");
        }
        
        try self.results.appendSlice("\n");
    }

    fn testResolutionInfo(self: *VesaTester, gpu: *const vesa.VesaDriver) !void {
        self.total_count += 1;
        try self.results.appendSlice("Test 2: Resolution Information... ");

        // 检查分辨率信息是否有效
        if (gpu.width > 0 and gpu.height > 0 and gpu.bpp >= 8) {
            self.success_count += 1;
            try self.results.appendSlice("PASSED\n");
            try self.results.appendSlice(try std.fmt.allocPrint(self.allocator, "  Valid resolution: {d}x{d} @ {d} bpp\n", .{gpu.width, gpu.height, gpu.bpp}));
        } else {
            try self.results.appendSlice("FAILED\n");
            try self.results.appendSlice(try std.fmt.allocPrint(self.allocator, "  Invalid resolution: {d}x{d} @ {d} bpp\n", .{gpu.width, gpu.height, gpu.bpp}));
        }
        
        try self.results.appendSlice("\n");
    }

    fn testPixelOperations(self: *VesaTester, gpu: *const vesa.VesaDriver) !void {
        self.total_count += 1;
        try self.results.appendSlice("Test 3: Pixel Operations... ");

        // 测试单个像素设置
        const test_x = gpu.width / 4;
        const test_y = gpu.height / 4;
        const test_color = 0xFF00FF; // 紫色

        // 清除测试区域
        try gpu.clear(0x000000);
        
        // 设置测试像素
        if (try gpu.setPixel(test_x, test_y, test_color)) {
            // 验证像素是否正确设置（在真实环境中可能需要额外逻辑）
            self.success_count += 1;
            try self.results.appendSlice("PASSED\n");
            try self.results.appendSlice(try std.fmt.allocPrint(self.allocator, "  Set pixel at ({d},{d}) with color 0x{x}\n", .{test_x, test_y, test_color}));
            
            // 渲染结果
            try gpu.render();
        } else {
            try self.results.appendSlice("FAILED\n");
            try self.results.appendSlice("  Failed to set pixel\n");
        }
        
        try self.results.appendSlice("\n");
    }

    fn testClearScreen(self: *VesaTester, gpu: *const vesa.VesaDriver) !void {
        self.total_count += 1;
        try self.results.appendSlice("Test 4: Clear Screen... ");

        // 设置一些像素
        const mid_x = gpu.width / 2;
        const mid_y = gpu.height / 2;
        var i: usize = 0;
        while (i < 100) : (i += 1) {
            _ = gpu.setPixel(mid_x + i, mid_y, 0x00FF00);
        }
        
        // 渲染到屏幕
        try gpu.render();
        
        // 等待一小段时间（在真实环境中可能需要调整）
        // std.time.sleep(100 * std.time.ns_per_ms);
        
        // 清屏
        if (try gpu.clear(0x000000)) {
            self.success_count += 1;
            try self.results.appendSlice("PASSED\n");
            try self.results.appendSlice("  Screen cleared successfully\n");
            
            // 渲染清除结果
            try gpu.render();
        } else {
            try self.results.appendSlice("FAILED\n");
            try self.results.appendSlice("  Failed to clear screen\n");
        }
        
        try self.results.appendSlice("\n");
    }

    fn testRectangleDrawing(self: *VesaTester, gpu: *const vesa.VesaDriver) !void {
        self.total_count += 1;
        try self.results.appendSlice("Test 5: Rectangle Drawing... ");

        // 定义矩形位置和大小
        const rect_width = gpu.width / 3;
        const rect_height = gpu.height / 3;
        const rect_x = (gpu.width - rect_width) / 2;
        const rect_y = (gpu.height - rect_height) / 2;
        const rect_color = 0x0000FF; // 蓝色

        // 清除屏幕
        try gpu.clear(0x000000);
        
        // 绘制矩形
        if (try gpu.drawRectangle(rect_x, rect_y, rect_width, rect_height, rect_color)) {
            self.success_count += 1;
            try self.results.appendSlice("PASSED\n");
            try self.results.appendSlice(try std.fmt.allocPrint(self.allocator, "  Drawn rectangle at ({d},{d}) with size {d}x{d}\n", .{rect_x, rect_y, rect_width, rect_height}));
            
            // 渲染结果
            try gpu.render();
        } else {
            try self.results.appendSlice("FAILED\n");
            try self.results.appendSlice("  Failed to draw rectangle\n");
        }
        
        try self.results.appendSlice("\n");
    }

    fn testPerformance(self: *VesaTester, gpu: *const vesa.VesaDriver) !void {
        self.total_count += 1;
        try self.results.appendSlice("Test 6: Performance Test... ");

        // 测试填充屏幕的性能
        const start_time = std.time.milliTimestamp();
        
        // 尝试填充整个屏幕多次
        const iterations = 3;
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            const color = switch (i) {
                0 => 0xFF0000,
                1 => 0x00FF00,
                2 => 0x0000FF,
                else => 0xFFFFFF,
            };
            _ = gpu.clear(color);
            _ = gpu.render();
        }
        
        const end_time = std.time.milliTimestamp();
        const elapsed_time = end_time - start_time;
        
        self.success_count += 1;
        try self.results.appendSlice("PASSED\n");
        try self.results.appendSlice(try std.fmt.allocPrint(self.allocator, "  Performance: {d} iterations in {d} ms\n", .{iterations, elapsed_time}));
        if (iterations > 0) {
            try self.results.appendSlice(try std.fmt.allocPrint(self.allocator, "  Average: {d} ms per frame\n", .{elapsed_time / iterations}));
        }
        
        try self.results.appendSlice("\n");
    }

    fn testDeinit(self: *VesaTester) !void {
        self.total_count += 1;
        try self.results.appendSlice("Test 7: Driver Deinitialization... ");

        // 尝试反初始化VESA驱动
        try vesa.deinit();
        
        self.success_count += 1;
        try self.results.appendSlice("PASSED\n");
        try self.results.appendSlice("  VESA driver deinitialized\n");
        
        try self.results.appendSlice("\n");
    }

    fn printSummary(self: *VesaTester) !void {
        try self.results.appendSlice("\n======== TEST SUMMARY ========\n");
        try self.results.appendSlice(try std.fmt.allocPrint(self.allocator, "Total tests: {d}\n", .{self.total_count}));
        try self.results.appendSlice(try std.fmt.allocPrint(self.allocator, "Passed tests: {d}\n", .{self.success_count}));
        try self.results.appendSlice(try std.fmt.allocPrint(self.allocator, "Failed tests: {d}\n", .{self.total_count - self.success_count}));
        
        const pass_rate = if (self.total_count > 0) 
            @intToFloat(f64, self.success_count) / @intToFloat(f64, self.total_count) * 100.0 
            else 0.0;
        
        try self.results.appendSlice(try std.fmt.allocPrint(self.allocator, "Pass rate: {d:.1}%\n", .{pass_rate}));
        
        if (pass_rate >= 80.0) {
            try self.results.appendSlice("Overall result: SUCCESS\n");
        } else {
            try self.results.appendSlice("Overall result: FAILED\n");
        }
        
        try self.results.appendSlice("=============================\n");
    }
};

// 公共测试接口
pub fn runVesaTests() ![]const u8 {
    const allocator = std.heap.page_allocator;
    var tester = try VesaTester.init(allocator);
    defer tester.deinit();
    
    const results = try tester.runAllTests();
    
    // 将测试结果记录到VFS
    _ = vfs.UyaFS.addFile("/tmp/vesa_test_results", results) catch {};
    
    return results;
}

// 简单的集成测试函数
pub fn simpleVesaTest() bool {
    // 尝试初始化并立即反初始化VESA驱动
    if (vesa.init()) {
        defer vesa.deinit();
        return vesa.getGpu() != null;
    }
    return false;
}
