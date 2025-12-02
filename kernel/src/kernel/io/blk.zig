const std = @import("std");

pub const SectorSize: usize = 512;

pub const ReadFn = fn (ctx: *anyopaque, lba: u64, count: usize, out: []u8) bool;
pub const WriteFn = fn (ctx: *anyopaque, lba: u64, data: []const u8) bool;

pub const Device = struct {
    ctx: *anyopaque,
    read: *const ReadFn,
    write: *const WriteFn,
};

var devices: [4]Device = undefined;
var dev_used: [4]bool = [_]bool{false} ** 4;

pub fn init() void {
    var i: usize = 0;
    while (i < devices.len) : (i += 1) dev_used[i] = false;
}

pub fn register(dev: Device) ?usize {
    var i: usize = 0;
    while (i < devices.len) : (i += 1) {
        if (!dev_used[i]) {
            devices[i] = dev;
            dev_used[i] = true;
            return i;
        }
    }
    return null;
}

pub fn read(dev_id: usize, lba: u64, count: usize, out: []u8) bool {
    if (dev_id >= devices.len or !dev_used[dev_id]) return false;
    if (out.len < count * SectorSize) return false;
    const d = devices[dev_id];
    return d.read(d.ctx, lba, count, out);
}

pub fn write(dev_id: usize, lba: u64, data: []const u8) bool {
    if (dev_id >= devices.len or !dev_used[dev_id]) return false;
    if ((data.len % SectorSize) != 0) return false;
    const d = devices[dev_id];
    return d.write(d.ctx, lba, data);
}