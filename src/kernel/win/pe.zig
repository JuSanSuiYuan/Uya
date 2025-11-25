pub const PE = struct {
    pub fn validate(img: []const u8) bool {
        if (img.len < 0x40) return false;
        if (!(img[0] == 'M' and img[1] == 'Z')) return false;
        const off = readU32LE(img, 0x3C);
        if (@as(usize, off) + 4 > img.len) return false;
        const p0 = img[@as(usize, off)];
        const p1 = img[@as(usize, off) + 1];
        const p2 = img[@as(usize, off) + 2];
        const p3 = img[@as(usize, off) + 3];
        return p0 == 'P' and p1 == 'E' and p2 == 0 and p3 == 0;
    }

    pub fn entryRva(img: []const u8) u32 {
        if (!PE.validate(img)) return 0;
        const e_lfanew = readU32LE(img, 0x3C);
        const coff = @as(usize, e_lfanew) + 4;
        if (coff + 20 > img.len) return 0;
        const opt_off = coff + 20;
        if (opt_off + @as(usize, readU16LE(img, coff + 16)) > img.len) return 0;
        const e = readU32LE(img, opt_off + 16);
        return e;
    }

    pub fn imageBase(img: []const u8) u64 {
        if (!PE.validate(img)) return 0;
        const e_lfanew = readU32LE(img, 0x3C);
        const coff = @as(usize, e_lfanew) + 4;
        const opt_off = coff + 20;
        const magic = readU16LE(img, opt_off + 0);
        if (magic != 0x20B) return 0;
        const base64 = readU64LE(img, opt_off + 24);
        return base64;
    }

    pub fn sizeOfImage(img: []const u8) u32 {
        if (!PE.validate(img)) return 0;
        const e_lfanew = readU32LE(img, 0x3C);
        const coff = @as(usize, e_lfanew) + 4;
        const opt_off = coff + 20;
        return readU32LE(img, opt_off + 56);
    }

    pub fn numberOfSections(img: []const u8) u16 {
        if (!PE.validate(img)) return 0;
        const e_lfanew = readU32LE(img, 0x3C);
        const coff = @as(usize, e_lfanew) + 4;
        return readU16LE(img, coff + 2);
    }

    pub fn sectionsOffset(img: []const u8) usize {
        const e_lfanew = readU32LE(img, 0x3C);
        const coff = @as(usize, e_lfanew) + 4;
        const opt_size = readU16LE(img, coff + 16);
        return coff + 20 + @as(usize, opt_size);
    }

    pub fn mapImage(img: []const u8, out: []u8) struct { base: u64, size: usize, entry: u64 } {
        var i: usize = 0;
        while (i < out.len) : (i += 1) out[i] = 0;
        const nsec = numberOfSections(img);
        const so = sectionsOffset(img);
        var idx: usize = 0;
        while (idx < nsec) : (idx += 1) {
            const off = so + idx * 40;
            const rva = readU32LE(img, off + 12);
            const sz = readU32LE(img, off + 16);
            const ptr = readU32LE(img, off + 20);
            var k: usize = 0;
            while (k < sz and (@as(usize, rva) + k) < out.len and (@as(usize, ptr) + k) < img.len) : (k += 1) {
                out[@as(usize, rva) + k] = img[@as(usize, ptr) + k];
            }
            const ch = readU32LE(img, off + 36);
            const prot = chooseProt(ch) orelse mm.Prot.r;
            const va = @as(usize, rva);
            const len = roundUp(@as(usize, sz), 4096);
            _ = mm.mm_map(undefined, va, va, len, prot);
        }
        const base = imageBase(img);
        _ = applyRelocs(img, out, 0);
        setSectionProtections(img);
        fillIat(img, out);
        const entry = @as(u64, base) + @as(u64, entryRva(img));
        return .{ .base = base, .size = out.len, .entry = entry };
    }

    pub fn importsCount(img: []const u8) u32 {
        const e_lfanew = readU32LE(img, 0x3C);
        const coff = @as(usize, e_lfanew) + 4;
        const opt_off = coff + 20;
        const magic = readU16LE(img, opt_off + 0);
        if (magic != 0x20B) return 0;
        const dd_off = opt_off + 112;
        const imp_rva = readU32LE(img, dd_off + 8);
        const imp_size = readU32LE(img, dd_off + 12);
        if (imp_rva == 0 or imp_size == 0) return 0;
        const so = sectionsOffset(img);
        const nsec = numberOfSections(img);
        const base = rvaToFileOff(img, imp_rva, so, nsec);
        if (base == null) return 0;
        var count: u32 = 0;
        var p: usize = base.?;
        const end: usize = p + @as(usize, imp_size);
        while (p + 20 <= end) : (p += 20) {
            const oft = readU32LE(img, p + 0);
            const tds = readU32LE(img, p + 4);
            const fwc = readU32LE(img, p + 8);
            const nm = readU32LE(img, p + 12);
            const ft = readU32LE(img, p + 16);
            if (oft == 0 and tds == 0 and fwc == 0 and nm == 0 and ft == 0) break;
            count += 1;
        }
        return count;
    }
    pub fn findExportRva(img: []const u8, name: []const u8) u32 {
        const e_lfanew = readU32LE(img, 0x3C);
        const coff = @as(usize, e_lfanew) + 4;
        const opt_off = coff + 20;
        const magic = readU16LE(img, opt_off + 0);
        if (magic != 0x20B) return 0;
        const dd_off = opt_off + 112;
        const exp_rva = readU32LE(img, dd_off + 0);
        const exp_size = readU32LE(img, dd_off + 4);
        if (exp_rva == 0 or exp_size == 0) return 0;
        const so = sectionsOffset(img);
        const nsec = numberOfSections(img);
        const base_off = rvaToFileOff(img, exp_rva, so, nsec) orelse return 0;
        const names_rva = readU32LE(img, base_off + 32);
        const ordinals_rva = readU32LE(img, base_off + 36);
        const funcs_rva = readU32LE(img, base_off + 28);
        const count = readU32LE(img, base_off + 24);
        const names_off = rvaToFileOff(img, names_rva, so, nsec) orelse return 0;
        const ord_off = rvaToFileOff(img, ordinals_rva, so, nsec) orelse return 0;
        const func_off = rvaToFileOff(img, funcs_rva, so, nsec) orelse return 0;
        var i: usize = 0;
        while (i < count) : (i += 1) {
            const nrva = readU32LE(img, names_off + i * 4);
            const noff = rvaToFileOff(img, nrva, so, nsec) orelse continue;
            const nm = readName(img, noff);
            if (eqStr(nm, name)) {
                const ord = readU16LE(img, ord_off + i * 2);
                const frva = readU32LE(img, func_off + @as(usize, ord) * 4);
                return frva;
            }
        }
        return 0;
    }
    pub fn exportVa(img: []const u8, name: []const u8) u64 {
        const rva = findExportRva(img, name);
        if (rva == 0) return 0;
        const base = imageBase(img);
        return base + @as(u64, rva);
    }
};

fn readU32LE(s: []const u8, o: usize) u32 {
    if (o + 4 > s.len) return 0;
    return @as(u32, s[o]) | (@as(u32, s[o+1]) << 8) | (@as(u32, s[o+2]) << 16) | (@as(u32, s[o+3]) << 24);
}

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

fn readStr8(s: []const u8, o: usize) [8]u8 {
    var out: [8]u8 = undefined;
    var i: usize = 0;
    while (i < 8) : (i += 1) out[i] = if (o + i < s.len) s[o + i] else 0;
    return out;
}

fn eq8(a: [8]u8, b_str: []const u8) bool {
    var i: usize = 0;
    while (i < 8 and i < b_str.len) : (i += 1) {
        if (a[i] != b_str[i]) return false;
    }
    return true;
}

fn rvaToFileOff(img: []const u8, rva: u32, so: usize, nsec: u16) ?usize {
    var idx: usize = 0;
    while (idx < nsec) : (idx += 1) {
        const off = so + idx * 40;
        const va = readU32LE(img, off + 12);
        const sz = readU32LE(img, off + 8);
        const ptr = readU32LE(img, off + 20);
        const r = @as(usize, rva);
        const v = @as(usize, va);
        const s = @as(usize, sz);
        if (r >= v and r < v + s) {
            return @as(usize, ptr) + (r - v);
        }
    }
    return null;
}

fn applyRelocs(img: []const u8, out: []u8, delta: u64) u32 {
    if (delta == 0) return 0;
    const e_lfanew = readU32LE(img, 0x3C);
    const coff = @as(usize, e_lfanew) + 4;
    const opt_off = coff + 20;
    const magic = readU16LE(img, opt_off + 0);
    if (magic != 0x20B) return 0;
    const dd_off = opt_off + 112;
    const br_rva = readU32LE(img, dd_off + 5 * 8 + 0);
    const br_size = readU32LE(img, dd_off + 5 * 8 + 4);
    if (br_rva == 0 or br_size == 0) return 0;
    const so = PE.sectionsOffset(img);
    const nsec = PE.numberOfSections(img);
    const base = rvaToFileOff(img, br_rva, so, nsec) orelse return 0;
    var applied: u32 = 0;
    var p: usize = base;
    const end: usize = base + @as(usize, br_size);
    while (p + 8 <= end) {
        const va = readU32LE(img, p + 0);
        const sz = readU32LE(img, p + 4);
        if (sz < 8) break;
        var q: usize = p + 8;
        const count = (sz - 8) / 2;
        var i: usize = 0;
        while (i < count) : (i += 1) {
            const ent = readU16LE(img, q);
            q += 2;
            const typ = (ent >> 12) & 0xF;
            const off = ent & 0x0FFF;
            if (typ == 0) continue;
            if (typ == 10) {
                const addr = @as(usize, va) + @as(usize, off);
                if (addr + 8 <= out.len) {
                    var v: u64 = @as(u64, out[addr])
                        | (@as(u64, out[addr+1]) << 8)
                        | (@as(u64, out[addr+2]) << 16)
                        | (@as(u64, out[addr+3]) << 24)
                        | (@as(u64, out[addr+4]) << 32)
                        | (@as(u64, out[addr+5]) << 40)
                        | (@as(u64, out[addr+6]) << 48)
                        | (@as(u64, out[addr+7]) << 56);
                    v += delta;
                    out[addr+0] = @as(u8, @intCast(v & 0xFF));
                    out[addr+1] = @as(u8, @intCast((v >> 8) & 0xFF));
                    out[addr+2] = @as(u8, @intCast((v >> 16) & 0xFF));
                    out[addr+3] = @as(u8, @intCast((v >> 24) & 0xFF));
                    out[addr+4] = @as(u8, @intCast((v >> 32) & 0xFF));
                    out[addr+5] = @as(u8, @intCast((v >> 40) & 0xFF));
                    out[addr+6] = @as(u8, @intCast((v >> 48) & 0xFF));
                    out[addr+7] = @as(u8, @intCast((v >> 56) & 0xFF));
                    applied += 1;
                }
            }
        }
        p += sz;
    }
    return applied;
}
const mm = @import("mm_core");
const api = @import("win_api");
const h = @import("win_handle");

fn setSectionProtections(img: []const u8) void {
    const so = PE.sectionsOffset(img);
    const nsec = PE.numberOfSections(img);
    var idx: usize = 0;
    while (idx < nsec) : (idx += 1) {
        const off = so + idx * 40;
        const rva = readU32LE(img, off + 12);
        const sz = readU32LE(img, off + 16);
        const ch = readU32LE(img, off + 36);
        const prot = chooseProt(ch);
        if (prot) |p| {
            const va = @as(usize, rva);
            const len = roundUp(@as(usize, sz), 4096);
            _ = mm.mm_protect(undefined, va, len, p);
        }
    }
}

fn chooseProt(ch: u32) ?mm.Prot {
    const EXEC: u32 = 0x2000_0000;
    const READ: u32 = 0x4000_0000;
    const WRITE: u32 = 0x8000_0000;
    if ((ch & EXEC) != 0) return .x;
    if ((ch & WRITE) != 0) return .w;
    if ((ch & READ) != 0) return .r;
    return null;
}

fn roundUp(x: usize, a: usize) usize { return ((x + a - 1) / a) * a; }

fn fillIat(img: []const u8, out: []u8) void {
    const e_lfanew = readU32LE(img, 0x3C);
    const coff = @as(usize, e_lfanew) + 4;
    const opt_off = coff + 20;
    const magic = readU16LE(img, opt_off + 0);
    if (magic != 0x20B) return;
    const dd_off = opt_off + 112;
    const imp_rva = readU32LE(img, dd_off + 8);
    const imp_size = readU32LE(img, dd_off + 12);
    if (imp_rva == 0 or imp_size == 0) return;
    const so = PE.sectionsOffset(img);
    const nsec = PE.numberOfSections(img);
    const base = rvaToFileOff(img, imp_rva, so, nsec) orelse return;
    var p: usize = base;
    const end: usize = base + @as(usize, imp_size);
    while (p + 20 <= end) : (p += 20) {
        const oft = readU32LE(img, p + 0);
        const tds = readU32LE(img, p + 4);
        const fwc = readU32LE(img, p + 8);
        const nm = readU32LE(img, p + 12);
        const ft = readU32LE(img, p + 16);
        if (oft == 0 and tds == 0 and fwc == 0 and nm == 0 and ft == 0) break;
        const ilt = if (oft != 0) oft else ft;
        const ilt_base = rvaToFileOff(img, ilt, so, nsec) orelse continue;
        var idx_thunk: usize = 0;
        while (true) : (idx_thunk += 1) {
            const th_off = ilt_base + idx_thunk * 8;
            if (th_off + 8 > img.len) break;
            const th_val = readU64LE(img, th_off);
            if (th_val == 0) break;
            const is_ordinal = (th_val & 0x8000_0000_0000_0000) != 0;
            var addr: u64 = 0;
            if (!is_ordinal) {
                const name_rva = @as(u32, @intCast(th_val & 0xFFFF_FFFF));
                const name_off = rvaToFileOff(img, name_rva, so, nsec) orelse continue;
                const nm_slice = readName(img, name_off + 2);
                if (resolveImportByName(nm_slice)) |a| addr = a;
            }
            const iat_rva = @as(usize, ft) + idx_thunk * 8;
            if (iat_rva + 8 <= out.len) {
                out[iat_rva+0] = @as(u8, @intCast(addr & 0xFF));
                out[iat_rva+1] = @as(u8, @intCast((addr >> 8) & 0xFF));
                out[iat_rva+2] = @as(u8, @intCast((addr >> 16) & 0xFF));
                out[iat_rva+3] = @as(u8, @intCast((addr >> 24) & 0xFF));
                out[iat_rva+4] = @as(u8, @intCast((addr >> 32) & 0xFF));
                out[iat_rva+5] = @as(u8, @intCast((addr >> 40) & 0xFF));
                out[iat_rva+6] = @as(u8, @intCast((addr >> 48) & 0xFF));
                out[iat_rva+7] = @as(u8, @intCast((addr >> 56) & 0xFF));
            }
        }
    }
}

fn readName(s: []const u8, o: usize) []const u8 {
    var end = o;
    while (end < s.len and s[end] != 0) : (end += 1) {}
    return s[o..end];
}

fn iat_GetFileSize(handle: h.Handle) u64 { return api.GetFileSize(handle); }
fn iat_CloseHandle(handle: h.Handle) u64 { return if (api.CloseHandle(handle)) 1 else 0; }
fn iat_CreateFileA(path: [*]const u8) u64 {
    var len: usize = 0;
    while (path[len] != 0) : (len += 1) {}
    var buf: [256]u8 = undefined;
    var i: usize = 0;
    while (i < len and i < 256) : (i += 1) buf[i] = path[i];
    const hnd = api.CreateFileA(buf[0..len]) orelse return 0;
    return hnd;
}

fn resolveImportByName(name: []const u8) ?u64 {
    if (eqStr(name, "GetFileSize")) return @intFromPtr(&iat_GetFileSize);
    if (eqStr(name, "CloseHandle")) return @intFromPtr(&iat_CloseHandle);
    if (eqStr(name, "CreateFileA")) return @intFromPtr(&iat_CreateFileA);
    return null;
}

fn eqStr(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    var i: usize = 0;
    while (i < a.len) : (i += 1) {
        if (a[i] != b[i]) return false;
    }
    return true;
}
