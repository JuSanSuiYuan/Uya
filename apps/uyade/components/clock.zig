pub const Mode = enum { horizontal, vertical_two_per_line };

pub const Clock = struct {
    mode: Mode,
    use_seconds: bool,
    hh: u8,
    mm: u8,
    ss: u8,

    pub fn init(mode: Mode, use_seconds: bool) Clock { return .{ .mode = mode, .use_seconds = use_seconds, .hh = 0, .mm = 0, .ss = 0 }; }

    pub fn set(self: *Clock, hh: u8, mm: u8, ss: u8) void { self.hh = hh; self.mm = mm; self.ss = ss; }

    pub fn formatVertical(self: *const Clock) struct { line1: [2]u8, line2: [2]u8, line3: ?[2]u8 } {
        const l1 = twoDigits(self.hh);
        const l2 = twoDigits(self.mm);
        const l3: ?[2]u8 = if (self.use_seconds) twoDigits(self.ss) else null;
        return .{ .line1 = l1, .line2 = l2, .line3 = l3 };
    }

    pub fn formatHorizontal(self: *const Clock) [8]u8 {
        var out: [8]u8 = [_]u8{ '0', '0', ':', '0', '0', 0, 0, 0 };
        const h = twoDigits(self.hh);
        const m = twoDigits(self.mm);
        out[0] = h[0]; out[1] = h[1];
        out[3] = m[0]; out[4] = m[1];
        if (self.use_seconds) {
            out[5] = ':';
            const s = twoDigits(self.ss);
            out[6] = s[0]; out[7] = s[1];
        }
        return out;
    }
};

fn twoDigits(x: u8) [2]u8 {
    const t: u8 = x % 100;
    return .{ @as(u8, '0') + @as(u8, @intCast(t / 10)), @as(u8, '0') + @as(u8, @intCast(t % 10)) };
}