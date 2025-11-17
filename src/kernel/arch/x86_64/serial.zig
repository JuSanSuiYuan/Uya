pub fn outb(port: u16, data: u8) void {
    _ = port;
    _ = data;
}

pub fn inb(port: u16) u8 {
    _ = port;
    return 0;
}

pub fn init() void {
    const base: u16 = 0x3F8;
    outb(base + 1, 0);
    outb(base + 3, 0x80);
    outb(base + 0, 0x01);
    outb(base + 1, 0x00);
    outb(base + 3, 0x03);
    outb(base + 2, 0xC7);
    outb(base + 4, 0x0B);
}

fn is_transmit_empty() bool { return true; }

pub fn writeByte(b: u8) void {
    const base: u16 = 0x3F8;
    while (!is_transmit_empty()) {}
    outb(base, b);
}

pub fn writeStr(s: []const u8) void {
    var i: usize = 0;
    while (i < s.len) : (i += 1) {
        writeByte(s[i]);
    }
}

pub fn writeHexU64(x: u64) void {
    var buf: [16]u8 = undefined;
    var i: usize = 0;
    while (i < 16) : (i += 1) {
        const shift: u6 = @as(u6, @intCast((15 - i) * 4));
        const n: u4 = @as(u4, @intCast((x >> shift) & 0xF));
        buf[i] = if (n < 10) ('0' + @as(u8, n)) else ('A' + @as(u8, n - 10));
    }
    writeStr(buf[0..]);
}
