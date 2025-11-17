pub const ELF = struct {
    pub fn validate(img: []const u8) bool {
        if (img.len < 64) return false;
        return img[0] == 0x7F and img[1] == 'E' and img[2] == 'L' and img[3] == 'F' and img[4] == 2 and img[5] == 1 and img[6] == 1;
    }

    pub fn segmentsCount(img: []const u8) u16 {
        if (!validate(img)) return 0;
        const phoff = readU64LE(img, 32);
        const phentsize = readU16LE(img, 54);
        const phnum = readU16LE(img, 56);
        if (@as(usize, phoff) + @as(usize, phentsize) * @as(usize, phnum) > img.len) return 0;
        return phnum;
    }
};

fn readU16LE(s: []const u8, o: usize) u16 {
    if (o + 2 > s.len) return 0;
    return @as(u16, s[o]) | (@as(u16, s[o+1]) << 8);
}

fn readU64LE(s: []const u8, o: usize) u64 {
    if (o + 8 > s.len) return 0;
    return @as(u64, s[o])
        | (@as(u64, s[o+1]) << 8)
        | (@as(u64, s[o+2]) << 16)
        | (@as(u64, s[o+3]) << 24)
        | (@as(u64, s[o+4]) << 32)
        | (@as(u64, s[o+5]) << 40)
        | (@as(u64, s[o+6]) << 48)
        | (@as(u64, s[o+7]) << 56);
}