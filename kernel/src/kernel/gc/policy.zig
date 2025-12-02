const zigmod = @import("plugin_zigmod");
var step_quota: usize = 8;
var target_pause_ticks: usize = 100;
pub const Model = enum { local, doubao, qwen, hunyuan, ensemble };
var active_model: Model = .ensemble;
pub fn get_step_quota() usize { return step_quota; }
pub fn set_step_quota(n: usize) void { step_quota = if (n == 0) 1 else n; }
pub fn set_target_pause(n: usize) void { target_pause_ticks = n; }
pub fn set_model(m: Model) void { active_model = m; }
pub fn get_model() Model { return active_model; }
pub fn decide(pause_ticks: usize, marked: usize, roots: usize, pinned: usize) void {
    if (pause_ticks > target_pause_ticks) step_quota = if (step_quota > 1) step_quota / 2 else 1 else step_quota = step_quota + 1;
    if (active_model == .local) return;
    if (active_model == .doubao and zigmod.get("gc_policy")) |tp| {
        var buf: [32]u8 = undefined;
        buf[0] = @as(u8, @intCast(pause_ticks & 0xFF));
        buf[1] = @as(u8, @intCast((pause_ticks >> 8) & 0xFF));
        buf[2] = @as(u8, @intCast(marked & 0xFF));
        buf[3] = @as(u8, @intCast((marked >> 8) & 0xFF));
        buf[4] = @as(u8, @intCast(roots & 0xFF));
        buf[5] = @as(u8, @intCast((roots >> 8) & 0xFF));
        buf[6] = @as(u8, @intCast(pinned & 0xFF));
        buf[7] = @as(u8, @intCast((pinned >> 8) & 0xFF));
        const out = tp.call.*(1001, buf[0..8]);
        if (out != 0) set_step_quota(out);
    } else if (active_model == .qwen and zigmod.get("gc_policy_qwen")) |tpq| {
        var b2: [8]u8 = undefined; b2[0] = @as(u8, @intCast(pause_ticks & 0xFF)); b2[1] = @as(u8, @intCast((pause_ticks >> 8) & 0xFF)); b2[2] = @as(u8, @intCast(marked & 0xFF)); b2[3] = @as(u8, @intCast((marked >> 8) & 0xFF)); b2[4] = @as(u8, @intCast(roots & 0xFF)); b2[5] = @as(u8, @intCast((roots >> 8) & 0xFF)); b2[6] = @as(u8, @intCast(pinned & 0xFF)); b2[7] = @as(u8, @intCast((pinned >> 8) & 0xFF));
        const out2 = tpq.call.*(1002, b2[0..]); if (out2 != 0) set_step_quota(out2);
    } else if (active_model == .hunyuan and zigmod.get("gc_policy_hunyuan")) |tph| {
        var b3: [8]u8 = undefined; b3[0] = @as(u8, @intCast(pause_ticks & 0xFF)); b3[1] = @as(u8, @intCast((pause_ticks >> 8) & 0xFF)); b3[2] = @as(u8, @intCast(marked & 0xFF)); b3[3] = @as(u8, @intCast((marked >> 8) & 0xFF)); b3[4] = @as(u8, @intCast(roots & 0xFF)); b3[5] = @as(u8, @intCast((roots >> 8) & 0xFF)); b3[6] = @as(u8, @intCast(pinned & 0xFF)); b3[7] = @as(u8, @intCast((pinned >> 8) & 0xFF));
        const out3 = tph.call.*(1003, b3[0..]); if (out3 != 0) set_step_quota(out3);
    } else if (active_model == .ensemble) {
        var votes: [3]usize = .{ step_quota, step_quota, step_quota };
        if (zigmod.get("gc_policy")) |tp| { var b: [8]u8 = undefined; // doubao
            b[0] = @as(u8, @intCast(pause_ticks & 0xFF)); b[1] = @as(u8, @intCast((pause_ticks >> 8) & 0xFF)); b[2] = @as(u8, @intCast(marked & 0xFF)); b[3] = @as(u8, @intCast((marked >> 8) & 0xFF)); b[4] = @as(u8, @intCast(roots & 0xFF)); b[5] = @as(u8, @intCast((roots >> 8) & 0xFF)); b[6] = @as(u8, @intCast(pinned & 0xFF)); b[7] = @as(u8, @intCast((pinned >> 8) & 0xFF)); const r = tp.call.*(1001, b[0..]); if (r != 0) votes[0] = r; }
        if (zigmod.get("gc_policy_qwen")) |tpq| { var bq: [8]u8 = undefined; bq[0] = @as(u8, @intCast(pause_ticks & 0xFF)); bq[1] = @as(u8, @intCast((pause_ticks >> 8) & 0xFF)); bq[2] = @as(u8, @intCast(marked & 0xFF)); bq[3] = @as(u8, @intCast((marked >> 8) & 0xFF)); bq[4] = @as(u8, @intCast(roots & 0xFF)); bq[5] = @as(u8, @intCast((roots >> 8) & 0xFF)); bq[6] = @as(u8, @intCast(pinned & 0xFF)); bq[7] = @as(u8, @intCast((pinned >> 8) & 0xFF)); const rq = tpq.call.*(1002, bq[0..]); if (rq != 0) votes[1] = rq; }
        if (zigmod.get("gc_policy_hunyuan")) |tph| { var bh: [8]u8 = undefined; bh[0] = @as(u8, @intCast(pause_ticks & 0xFF)); bh[1] = @as(u8, @intCast((pause_ticks >> 8) & 0xFF)); bh[2] = @as(u8, @intCast(marked & 0xFF)); bh[3] = @as(u8, @intCast((marked >> 8) & 0xFF)); bh[4] = @as(u8, @intCast(roots & 0xFF)); bh[5] = @as(u8, @intCast((roots >> 8) & 0xFF)); bh[6] = @as(u8, @intCast(pinned & 0xFF)); bh[7] = @as(u8, @intCast((pinned >> 8) & 0xFF)); const rh = tph.call.*(1003, bh[0..]); if (rh != 0) votes[2] = rh; }
        var minq: usize = votes[0]; if (votes[1] < minq) minq = votes[1]; if (votes[2] < minq) minq = votes[2]; set_step_quota(minq);
    }
}
pub fn decide_card_size(dirty_cards: usize, pause_ticks: usize) usize {
    var out: usize = 64;
    if (active_model == .qwen and @import("plugin_zigmod").get("gc_policy_qwen")) |tpq| {
        var b: [4]u8 = undefined; b[0] = @as(u8, @intCast(dirty_cards & 0xFF)); b[1] = @as(u8, @intCast((dirty_cards >> 8) & 0xFF)); b[2] = @as(u8, @intCast(pause_ticks & 0xFF)); b[3] = @as(u8, @intCast((pause_ticks >> 8) & 0xFF));
        const r = tpq.call.*(2002, b[0..]); if (r != 0) out = r;
    }
    if (out < 32) out = 32; if (out > 256) out = 256; return out;
}
pub fn decide_nursery_size(pause_ticks: usize, marked: usize, roots: usize) usize {
    var out: usize = 256 * 1024;
    if (active_model == .hunyuan and @import("plugin_zigmod").get("gc_policy_hunyuan")) |tph| {
        var b: [6]u8 = undefined; b[0] = @as(u8, @intCast(pause_ticks & 0xFF)); b[1] = @as(u8, @intCast((pause_ticks >> 8) & 0xFF)); b[2] = @as(u8, @intCast(marked & 0xFF)); b[3] = @as(u8, @intCast((marked >> 8) & 0xFF)); b[4] = @as(u8, @intCast(roots & 0xFF)); b[5] = @as(u8, @intCast((roots >> 8) & 0xFF));
        const r = tph.call.*(2003, b[0..]); if (r != 0) out = r;
    }
    if (out < 64 * 1024) out = 64 * 1024; if (out > 4 * 1024 * 1024) out = 4 * 1024 * 1024; return out;
}
pub fn decide_compaction_threshold(pinned: usize, pause_ticks: usize) usize {
    var out: usize = 50;
    if (active_model == .hunyuan and @import("plugin_zigmod").get("gc_policy_hunyuan")) |tph| {
        var b: [4]u8 = undefined; b[0] = @as(u8, @intCast(pinned & 0xFF)); b[1] = @as(u8, @intCast((pinned >> 8) & 0xFF)); b[2] = @as(u8, @intCast(pause_ticks & 0xFF)); b[3] = @as(u8, @intCast((pause_ticks >> 8) & 0xFF));
        const r = tph.call.*(2004, b[0..]); if (r != 0) out = r;
    }
    if (out < 10) out = 10; if (out > 90) out = 90; return out;
}
pub fn decide_roots_priority(dirty_cards: usize, roots: usize) usize {
    var out: usize = 0;
    if (active_model == .qwen and @import("plugin_zigmod").get("gc_policy_qwen")) |tpq| {
        var b: [4]u8 = undefined; b[0] = @as(u8, @intCast(dirty_cards & 0xFF)); b[1] = @as(u8, @intCast((dirty_cards >> 8) & 0xFF)); b[2] = @as(u8, @intCast(roots & 0xFF)); b[3] = @as(u8, @intCast((roots >> 8) & 0xFF));
        const r = tpq.call.*(2005, b[0..]); if (r != 0) out = r;
    }
    return out;
}
