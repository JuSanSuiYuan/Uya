const events = @import("events");

pub const Service = enum { fs, process, ipc };
var core_for: [3]usize = .{ 0, 0, 0 };

pub fn init(core_count: usize) void {
    core_for[@intFromEnum(Service.fs)] = 0;
    core_for[@intFromEnum(Service.process)] = if (core_count > 1) 1 else 0;
    core_for[@intFromEnum(Service.ipc)] = 0;
}

pub fn dispatch(s: Service, data: []const u8) bool {
    const cid = core_for[@intFromEnum(s)];
    return events.per_core_send(cid, data);
}