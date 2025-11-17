pub fn next(s: []const u8, start: usize) struct { cp: u32, len: usize } {
    if (start >= s.len) return .{ .cp = 0, .len = 0 };
    const b0 = s[start];
    if (b0 < 0x80) return .{ .cp = b0, .len = 1 };
    if ((b0 & 0xE0) == 0xC0 and start + 1 < s.len) {
        const b1 = s[start + 1];
        const cp = (@as(u32, b0 & 0x1F) << 6) | @as(u32, b1 & 0x3F);
        return .{ .cp = cp, .len = 2 };
    }
    if ((b0 & 0xF0) == 0xE0 and start + 2 < s.len) {
        const b1 = s[start + 1];
        const b2 = s[start + 2];
        const cp = (@as(u32, b0 & 0x0F) << 12) | (@as(u32, b1 & 0x3F) << 6) | @as(u32, b2 & 0x3F);
        return .{ .cp = cp, .len = 3 };
    }
    if ((b0 & 0xF8) == 0xF0 and start + 3 < s.len) {
        const b1 = s[start + 1];
        const b2 = s[start + 2];
        const b3 = s[start + 3];
        const cp = (@as(u32, b0 & 0x07) << 18) | (@as(u32, b1 & 0x3F) << 12) | (@as(u32, b2 & 0x3F) << 6) | @as(u32, b3 & 0x3F);
        return .{ .cp = cp, .len = 4 };
    }
    return .{ .cp = 0xFFFD, .len = 1 };
}