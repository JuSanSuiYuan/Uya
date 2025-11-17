const events = @import("events");
const percpu = @import("arch/x86_64/percpu.zig");

pub var core_n: usize = 1;

pub const Task = struct { id: u32, len: u16, data: [64]u8 };

pub fn init(n: usize) void { core_n = n; }

pub fn enqueue(core_id: usize, t: Task) bool { return events.per_core_send(core_id, t.data[0..t.len]); }

pub fn poll(core_id: usize) ?[]const u8 { return events.per_core_recv(core_id); }
pub fn run_once(core_id: usize) void {
    if (poll(core_id)) |data| {
        const pc = percpu.get(core_id);
        pc.tasks_processed += 1;
        _ = data;
    }
}

const ReadyQueue = struct {
    head: usize,
    tail: usize,
    buf: [128]Task,
    pub fn push(self: *ReadyQueue, t: Task) bool {
        const next = (self.tail + 1) % self.buf.len;
        if (next == self.head) return false;
        self.buf[self.tail] = t;
        self.tail = next;
        return true;
    }
    pub fn pop(self: *ReadyQueue) ?Task {
        if (self.head == self.tail) return null;
        const t = self.buf[self.head];
        self.head = (self.head + 1) % self.buf.len;
        return t;
    }
};

var ready: [8]ReadyQueue = [_]ReadyQueue{ .{ .head = 0, .tail = 0, .buf = undefined } } ** 8;
pub fn enqueue_ready(core_id: usize, t: Task) bool { return ready[core_id].push(t); }
pub fn run_ready(core_id: usize) void {
    if (ready[core_id].pop()) |task| {
        const pc = percpu.get(core_id);
        pc.tasks_processed += 1;
        _ = task;
    }
}