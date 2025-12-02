var global_epoch: u32 = 0;
const MaxCores: usize = 64;
var core_count: usize = 0;
var global_active: u32 = 0;
var core_active: [MaxCores]u32 = [_]u32{0} ** MaxCores;
var core_epoch: [MaxCores]u32 = [_]u32{0} ** MaxCores;

pub const Token = struct { epoch: u32 };

pub fn set_core_count(n: usize) void { core_count = if (n > MaxCores) MaxCores else n; }

pub fn enter() Token { global_active +%= 1; return .{ .epoch = global_epoch }; }
pub fn exit(_: Token) void { if (global_active > 0) global_active -%= 1; }

pub fn enter_core(core_id: usize) void {
    if (core_id >= core_count) return;
    core_active[core_id] +%= 1;
    core_epoch[core_id] = global_epoch;
}

pub fn exit_core(core_id: usize) void {
    if (core_id >= core_count) return;
    if (core_active[core_id] > 0) core_active[core_id] -%= 1;
}

pub fn advance_all_cores() void { global_epoch +%= 1; }

pub fn is_reclaimable(e: u32) bool {
    if (e == global_epoch) return false;
    if (global_active != 0) return false;
    var i: usize = 0;
    while (i < core_count) : (i += 1) {
        if (core_active[i] != 0 and core_epoch[i] == e) return false;
    }
    return true;
}

pub fn retire(_: *anyopaque) void {}