const std = @import("std");
const testing = std.testing;
const graphics = @import("../kernel/drivers/graphics.zig");
const input = @import("../kernel/drivers/input.zig");
const manager = @import("../kernel/drivers/manager.zig");

// 测试显卡驱动
fn testGraphicsDriver() !void {
    var allocator = testing.allocator;
    
    // 初始化一个小的显卡驱动
    const gpu = try graphics.GraphicsDriver.init(640, 480, allocator);
    defer gpu.deinit(allocator);
    
    // 测试像素设置
    try testing.expect(gpu.setPixel(10, 10, 255, 0, 0, 255)); // 红色像素
    try testing.expect(gpu.setPixel(640, 480, 0, 255, 0, 255) == false); // 越界像素
    
    // 测试清屏
    gpu.clear(0, 0, 255, 255); // 蓝色清屏
    
    // 测试渲染
    gpu.render();
    
    std.debug.print("✓ Graphics driver test passed\n", .{});
}

// 测试输入驱动
fn testInputDriver() !void {
    var allocator = testing.allocator;
    
    // 初始化输入驱动
    const input_driver = try input.InputDriver.init(allocator);
    defer input_driver.deinit(allocator);
    
    // 测试键盘事件
    try input_driver.pushEvent(.{ .keyboard = .{ 
        .keycode = 65, // 'A'键
        .pressed = true,
        .modifiers = 0
    }});
    
    // 测试鼠标事件
    try input_driver.pushEvent(.{ .mouse = .{ 
        .x = 100,
        .y = 200,
        .delta_x = 10,
        .delta_y = -5,
        .buttons = 1
    }});
    
    // 测试事件队列
    try testing.expect(input_driver.getEventsCount() == 2);
    const event1 = input_driver.popEvent();
    try testing.expect(event1 != null);
    
    std.debug.print("✓ Input driver test passed\n", .{});
}

// 测试驱动管理器
fn testDriverManager() !void {
    // 测试初始化
    const init_success = manager.DriverManager.init();
    try testing.expect(init_success);
    
    // 测试状态获取
    const status = manager.DriverManager.getStatus();
    std.debug.print("Driver status: {s}\n", .{status});
    
    // 测试反初始化
    manager.DriverManager.deinit();
    
    std.debug.print("✓ Driver manager test passed\n", .{});
}

// 运行所有测试
pub fn runTests() !void {
    std.debug.print("Running Uya driver tests...\n", .{});
    
    try testGraphicsDriver();
    try testInputDriver();
    try testDriverManager();
    
    std.debug.print("All tests passed!\n", .{});
}

pub fn main() !void {
    try runTests();
}
