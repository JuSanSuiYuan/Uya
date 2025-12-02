const mark = @import("gc_mark");
const pol = @import("gc_policy");
const api = @import("gc_api");
pub fn per_core_step(limit: usize) void { var i: usize = 0; while (i < limit) : (i += 1) mark.step(); }
pub fn step_all(loops: usize) void { var i: usize = 0; while (i < loops) : (i += 1) mark.step(); api.end_cycle(); }
pub fn measure_pause(core: usize, loops: usize) usize {
    const percpu = @import("arch/x86_64/percpu.zig");
    const before = percpu.get(core).*.ticks;
    step_all(loops);
    const after = percpu.get(core).*.ticks;
    return if (after >= before) (after - before) else 0;
}
pub fn step_policy(core: usize) usize { const quota = pol.get_step_quota(); return measure_pause(core, quota); }
