const serial = @import("arch/x86_64/serial.zig");
pub fn info(msg: []const u8) void { _ = msg; serial.init(); }