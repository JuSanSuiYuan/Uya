const fs = @import("fs_vfs");
const mm = @import("mm_core");

pub const Proc = struct { pid: u32, entry: usize, ran: bool };

pub fn create_from_elf(path: []const u8, pid: u32) ?Proc {
    const buf_opt = fs.UyaFS.read(path);
    if (buf_opt == null) return null;
    _ = mm.mm_map(undefined, 0x400000, 0x400000, 4096, .r);
    _ = mm.mm_protect(undefined, 0x400000, 4096, .x);
    return .{ .pid = pid, .entry = 0x400000, .ran = false };
}

pub fn run(p: *Proc) void { p.ran = true; }