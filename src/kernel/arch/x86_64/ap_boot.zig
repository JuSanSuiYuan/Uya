pub var ap_started_flags: [64]bool = [_]bool{false} ** 64;
pub var ap_count_started: u32 = 0;

pub fn start(smp_count: u32) void {
    var i: u32 = 1;
    while (i < smp_count and i < 64) : (i += 1) {
        ap_started_flags[@as(usize, @intCast(i))] = true;
    }
    ap_count_started = if (smp_count > 1) smp_count - 1 else 0;
}

pub fn is_started(core_id: u32) bool {
    if (core_id >= 64) return false;
    return ap_started_flags[@as(usize, @intCast(core_id))];
}