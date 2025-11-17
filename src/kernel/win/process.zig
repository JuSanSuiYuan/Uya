const vfs = @import("fs_vfs");
const pe = @import("win_pe");
const h = @import("win_handle");
const persona = @import("abi_persona");

pub const Process = struct { id: u64, ht: h.HandleTable, entry: u64, imports: u32, kind: persona.Persona };
var space: [2097152]u8 = undefined;

pub fn create(path: []const u8) ?Process {
    const data = vfs.UyaFS.read(path) orelse return null;
    if (!pe.PE.validate(data)) return null;
    const img = pe.PE.mapImage(data, space[0..]);
    const imp = pe.PE.importsCount(data);
    var ht = h.HandleTable.init();
    return .{ .id = ht.alloc(), .ht = ht, .entry = img.entry, .imports = imp, .kind = .win64 };
}

pub fn create_linux() Process {
    var ht = h.HandleTable.init();
    return .{ .id = ht.alloc(), .ht = ht, .entry = 0, .imports = 0, .kind = .linux };
}

pub fn create_bsd() Process {
    var ht = h.HandleTable.init();
    return .{ .id = ht.alloc(), .ht = ht, .entry = 0, .imports = 0, .kind = .bsd };
}