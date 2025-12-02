const st2 = @import("stivale2.zig");

pub var cpu_count: u32 = 1;

pub const Cpu = struct { id: u32, is_bsp: bool };
pub var cpus: [64]Cpu = undefined;

pub fn init(s: *st2.Struct) void {
    if (st2.getSmpCoreCount(s)) |n| {
        cpu_count = @as(u32, @intCast(n));
    } else {
        cpu_count = 1;
    }
    var i: u32 = 0;
    while (i < cpu_count) : (i += 1) {
        cpus[@as(usize, @intCast(i))] = .{ .id = i, .is_bsp = i == 0 };
    }
}

pub fn get_count() u32 { return cpu_count; }