const blk = @import("io_blk");

pub const RamDisk = struct {
    storage: []u8,
    pub fn readFn(ctx: *anyopaque, lba: u64, count: usize, out: []u8) bool {
        const self: *RamDisk = @ptrCast(@alignCast(ctx));
        const off: usize = @as(usize, @intCast(lba)) * blk.SectorSize;
        const len: usize = count * blk.SectorSize;
        if (off + len > self.storage.len) return false;
        var i: usize = 0;
        while (i < len) : (i += 1) out[i] = self.storage[off + i];
        return true;
    }
    pub fn writeFn(ctx: *anyopaque, lba: u64, data: []const u8) bool {
        const self: *RamDisk = @ptrCast(@alignCast(ctx));
        if ((data.len % blk.SectorSize) != 0) return false;
        const off: usize = @as(usize, @intCast(lba)) * blk.SectorSize;
        if (off + data.len > self.storage.len) return false;
        var i: usize = 0;
        while (i < data.len) : (i += 1) self.storage[off + i] = data[i];
        return true;
    }
};

var backing: [1024 * blk.SectorSize]u8 = undefined; // 512 KiB
var dev_obj: RamDisk = .{ .storage = backing[0..] };
var dev_id: ?usize = null;

pub fn init() ?usize {
    const d: blk.Device = .{ .ctx = &dev_obj, .read = RamDisk.readFn, .write = RamDisk.writeFn };
    dev_id = blk.register(d);
    return dev_id;
}

pub fn id() ?usize { return dev_id; }