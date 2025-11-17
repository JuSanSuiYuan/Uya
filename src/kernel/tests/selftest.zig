const events = @import("events");
const cap_epoch = @import("cap_epoch");

pub fn run() void {
    events.mpmc_global_init();
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        var buf: [32]u8 = undefined;
        const n = i % buf.len;
        var k: usize = 0;
        while (k < n) : (k += 1) buf[k] = @as(u8, @intCast(k));
        _ = events.mpmc_global_push(buf[0..n]);
        if ((i % 7) == 0) cap_epoch.advance_all_cores();
        if ((i % 3) == 0) {
            _ = events.mpmc_global_pop();
        }
    }
    var drain: usize = 0;
    while (drain < 100) : (drain += 1) {
        _ = events.mpmc_global_pop();
        cap_epoch.advance_all_cores();
    }
}