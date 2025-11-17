const events = @import("events");

pub var ap_started: bool = false;

pub fn launch(n: usize) void {
    if (n > 1) {
        ap_started = true;
        events.per_core_broadcast("ap_start");
        var i: usize = 1;
        while (i < n and i < 64) : (i += 1) {
            ap_entry(@as(u32, @intCast(i)));
        }
    }
}

pub fn ap_entry(core_id: u32) void {
    _ = core_id;
}