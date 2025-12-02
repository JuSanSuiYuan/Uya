const blk = @import("io_blk");
const vfs = @import("fs_vfs");

const PoolSize = 64 * 1024;
var pool: [PoolSize]u8 = undefined;
var pool_off: usize = 0;

fn alloc(n: usize) ?[]u8 {
    if (pool_off + n > PoolSize) return null;
    const s = pool[pool_off .. pool_off + n];
    pool_off += n;
    return s;
}

fn rd(dev: usize, lba: u64, count: usize, out: []u8) bool { return blk.read(dev, lba, count, out); }

fn u16le(b: []const u8, o: usize) u16 { return @as(u16, b[o]) | (@as(u16, b[o+1]) << 8); }
fn u32le(b: []const u8, o: usize) u32 { return @as(u32, b[o]) | (@as(u32, b[o+1]) << 8) | (@as(u32, b[o+2]) << 16) | (@as(u32, b[o+3]) << 24); }

pub fn mount(dev: usize, prefix: []const u8) bool {
    var sec0: [512]u8 = undefined;
    if (!rd(dev, 0, 1, sec0[0..])) return false;
    const bps = u16le(sec0[0..], 11);
    if (bps != 512) return false;
    const spc = sec0[13];
    const rsvd = u16le(sec0[0..], 14);
    const nf = sec0[16];
    const tot32 = u32le(sec0[0..], 32);
    const fatsz = u32le(sec0[0..], 36);
    const rootclus = u32le(sec0[0..], 44);
    if (spc == 0 or nf == 0 or fatsz == 0 or rootclus < 2 or tot32 == 0) return false;
    const fat_lba: u64 = rsvd;
    const data_lba: u64 = @as(u64, rsvd) + @as(u64, nf) * @as(u64, fatsz);

    var fatsec: [512]u8 = undefined;
    if (!rd(dev, fat_lba, 1, fatsec[0..])) return false;

    var dirsec: [512]u8 = undefined;
    const root_lba: u64 = data_lba + @as(u64, (rootclus - 2)) * @as(u64, spc);
    if (!rd(dev, root_lba, 1, dirsec[0..])) return false;

    var i: usize = 0;
    while (i + 32 <= 512) : (i += 32) {
        const name0 = dirsec[i];
        if (name0 == 0x00) break;
        if (name0 == 0xE5) continue;
        const attr = dirsec[i + 11];
        if ((attr & 0x08) != 0) continue;
        if ((attr & 0x10) != 0) continue;
        var nm: [12]u8 = undefined;
        var nmlen: usize = 0;
        var j: usize = 0;
        while (j < 11) : (j += 1) {
            const ch = dirsec[i + j];
            if (j == 8) { nm[nmlen] = '.'; nmlen += 1; }
            if (ch == ' ') continue;
            nm[nmlen] = ch;
            nmlen += 1;
        }
        const lo = u16le(dirsec[0..], i + 26);
        const hi = u16le(dirsec[0..], i + 20);
        const firstclus = (@as(u32, hi) << 16) | @as(u32, lo);
        const fsize = u32le(dirsec[0..], i + 28);
        if (firstclus < 2 or fsize == 0) continue;
        var remain: usize = fsize;
        var outbuf = alloc(fsize) orelse continue;
        var out_off: usize = 0;
        var clus = firstclus;
        var guard: usize = 0;
        while (remain > 0 and guard < 128) : (guard += 1) {
            const lba = data_lba + @as(u64, (clus - 2)) * @as(u64, spc);
            var sec: [512]u8 = undefined;
            if (!rd(dev, lba, 1, sec[0..])) break;
            const tocopy: usize = if (remain > 512) 512 else remain;
            var k: usize = 0;
            while (k < tocopy) : (k += 1) outbuf[out_off + k] = sec[k];
            out_off += tocopy;
            remain -= tocopy;
            const fat_off: usize = @as(usize, clus) * 4;
            const fat_sec_idx: u64 = @as(u64, fat_off / 512);
            var fat_block: [512]u8 = undefined;
            if (!rd(dev, fat_lba + fat_sec_idx, 1, fat_block[0..])) break;
            const ent = u32le(fat_block[0..], fat_off % 512);
            if ((ent & 0x0FFFFFFF) >= 0x0FFFFFF8) break;
            clus = ent & 0x0FFFFFFF;
        }
        var full: [256]u8 = undefined;
        var p: usize = 0;
        var k2: usize = 0;
        while (k2 < prefix.len) : (k2 += 1) { full[p] = prefix[k2]; p += 1; }
        if (p > 0 and full[p-1] != '/') { full[p] = '/'; p += 1; }
        k2 = 0;
        while (k2 < nmlen) : (k2 += 1) { full[p] = nm[k2]; p += 1; }
        _ = vfs.UyaFS.addFile(full[0..p], outbuf);
    }
    return true;
}