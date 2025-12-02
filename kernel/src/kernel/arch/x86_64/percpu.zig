pub var per_cpu_n: usize = 0;
pub const PerCpu = struct { id: usize, tasks_processed: u64, ticks: u64 };
pub var per_cpus: [8]PerCpu = undefined;
pub fn init(n: usize) void {
    per_cpu_n = if (n > 8) 8 else n;
    var i: usize = 0;
    while (i < per_cpu_n) : (i += 1) {
        per_cpus[i] = .{ .id = i, .tasks_processed = 0, .ticks = 0 };
    }
}
pub fn get(i: usize) *PerCpu { return &per_cpus[i]; }
pub fn count() usize { return per_cpu_n; }
pub fn tick(core_id: usize) void { per_cpus[core_id].ticks += 1; }