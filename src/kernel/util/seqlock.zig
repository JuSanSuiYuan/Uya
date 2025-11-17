pub fn SeqLock(comptime T: type) type {
    return struct {
        seq: u32,
        value: T,

        pub fn init(v: T) @This() {
            return .{ .seq = 0, .value = v };
        }

        pub fn write(self: *@This(), v: T) void {
            const p: *volatile u32 = &self.seq;
            const s1 = atomic.loadU32(p);
            atomic.storeU32(p, s1 + 1);
            self.value = v;
            atomic.storeU32(p, s1 + 2);
        }

        pub fn read(self: *@This(), out: *T) bool {
            const p: *volatile u32 = &self.seq;
            const s1 = atomic.loadU32(p);
            if ((s1 & 1) != 0) return false;
            const v = self.value;
            const s2 = atomic.loadU32(p);
            if ((s1 == s2) and ((s2 & 1) == 0)) { out.* = v; return true; }
            return false;
        }
    };
}
const atomic = @import("compat_atomic");
