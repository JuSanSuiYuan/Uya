const Header = packed struct {
    magic: u32,
    version: u32,
    headersize: u32,
    flags: u32,
    numglyph: u32,
    bytesperglyph: u32,
    height: u32,
    width: u32,
};

pub const Font = struct {
    data: []const u8,
    hdr: Header,

    pub fn initFromBytes(bytes: []const u8) ?Font {
        if (bytes.len < @sizeOf(Header)) return null;
        var h: Header = undefined;
        // Read little-endian fields
        h.magic = readU32(bytes, 0);
        h.version = readU32(bytes, 4);
        h.headersize = readU32(bytes, 8);
        h.flags = readU32(bytes, 12);
        h.numglyph = readU32(bytes, 16);
        h.bytesperglyph = readU32(bytes, 20);
        h.height = readU32(bytes, 24);
        h.width = readU32(bytes, 28);
        if (h.magic != 0x864ab572) return null;
        if (h.headersize > bytes.len) return null;
        return .{ .data = bytes, .hdr = h };
    }

    pub fn drawGlyph(self: *const Font, fb_put: fn (usize, usize, u32) void, x: usize, y: usize, codepoint: u32, color: u32) void {
        const idx: usize = if (codepoint < self.hdr.numglyph) @as(usize, codepoint) else 0;
        const off = self.hdr.headersize + idx * self.hdr.bytesperglyph;
        if (off + self.hdr.bytesperglyph > self.data.len) return;
        var row: usize = 0;
        while (row < self.hdr.height) : (row += 1) {
            var col: usize = 0;
            var byte: u8 = 0;
            var bitmask: u8 = 0;
            while (col < self.hdr.width) : (col += 1) {
                if (bitmask == 0) {
                    const b_off = off + row * (self.hdr.bytesperglyph / self.hdr.height) + (col / 8);
                    byte = self.data[b_off];
                    bitmask = 0x80;
                }
                if ((byte & bitmask) != 0) fb_put(x + col, y + row, color);
                bitmask >>= 1;
            }
        }
    }
};

fn readU32(s: []const u8, o: usize) u32 {
    return @as(u32, s[o]) | (@as(u32, s[o+1]) << 8) | (@as(u32, s[o+2]) << 16) | (@as(u32, s[o+3]) << 24);
}