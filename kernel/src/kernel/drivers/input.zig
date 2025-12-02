const std = @import("std");
const vfs = @import("fs_vfs");

pub const InputEvent = union(enum) {
    keyboard: struct {
        keycode: u16,
        pressed: bool,
        modifiers: u8,
    },
    mouse: struct {
        x: i32,
        y: i32,
        delta_x: i32,
        delta_y: i32,
        buttons: u8,
    },
    other: []const u8,
};

pub const InputDriver = struct {
    event_queue: std.ArrayList(InputEvent),
    
    pub fn init(allocator: std.mem.Allocator) !*InputDriver {
        const self = try allocator.create(InputDriver);
        self.* = .{
            .event_queue = std.ArrayList(InputEvent).init(allocator),
        };
        return self;
    }
    
    pub fn deinit(self: *InputDriver, allocator: std.mem.Allocator) void {
        self.event_queue.deinit();
        allocator.destroy(self);
    }
    
    pub fn pushEvent(self: *InputDriver, event: InputEvent) !void {
        try self.event_queue.append(event);
        // 记录事件到日志
        const event_str = try formatEvent(allocator, event);
        defer allocator.free(event_str);
        _ = vfs.UyaFS.addFile("/tmp/input_events", event_str) catch {};
    }
    
    pub fn popEvent(self: *InputDriver) ?InputEvent {
        if (self.event_queue.items.len == 0) return null;
        return self.event_queue.orderedRemove(0);
    }
    
    pub fn getEventsCount(self: *InputDriver) usize {
        return self.event_queue.items.len;
    }
};

fn formatEvent(allocator: std.mem.Allocator, event: InputEvent) ![]const u8 {
    return switch (event) {
        .keyboard => |kbd| {
            return std.fmt.allocPrint(allocator, "Keyboard: key={d}, pressed={}, mods={b}", .{kbd.keycode, kbd.pressed, kbd.modifiers});
        },
        .mouse => |mouse| {
            return std.fmt.allocPrint(allocator, "Mouse: x={d}, y={d}, dx={d}, dy={d}, btns={b}", .{mouse.x, mouse.y, mouse.delta_x, mouse.delta_y, mouse.buttons});
        },
        .other => |data| {
            return std.fmt.allocPrint(allocator, "Other: {s}", .{data});
        },
    };
}

// 默认输入设备
var default_input: ?*InputDriver = null;

pub fn init() bool {
    const allocator = std.heap.page_allocator;
    default_input = InputDriver.init(allocator) catch return false;
    return true;
}

pub fn getInput() ?*InputDriver {
    return default_input;
}

pub fn deinit() void {
    if (default_input) |input| {
        input.deinit(std.heap.page_allocator);
        default_input = null;
    }
}

// 模拟输入事件的测试函数
pub fn simulateKeyEvent(keycode: u16, pressed: bool) !void {
    if (default_input) |input| {
        try input.pushEvent(.{
            .keyboard = .{
                .keycode = keycode,
                .pressed = pressed,
                .modifiers = 0,
            },
        });
    }
}

pub fn simulateMouseEvent(x: i32, y: i32, dx: i32, dy: i32, buttons: u8) !void {
    if (default_input) |input| {
        try input.pushEvent(.{
            .mouse = .{
                .x = x,
                .y = y,
                .delta_x = dx,
                .delta_y = dy,
                .buttons = buttons,
            },
        });
    }
}
