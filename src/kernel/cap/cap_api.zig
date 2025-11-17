const T = @import("cap_types");

pub fn make(base: usize, len: usize, perms: T.Perms, otype: T.OType, obj_id: u64) T.Cap {
    return .{ .base = base, .len = len, .perms = perms, .otype = otype, .sealed = false, .tag = true, .epoch = 0, .obj_id = obj_id };
}

pub fn attenuate(c: T.Cap, mask: T.Perms) T.Cap {
    var p = c.perms;
    p.R = p.R and mask.R;
    p.W = p.W and mask.W;
    p.X = p.X and mask.X;
    p.Transfer = p.Transfer and mask.Transfer;
    p.Seal = p.Seal and mask.Seal;
    p.Mutate = p.Mutate and mask.Mutate;
    return .{ .base = c.base, .len = c.len, .perms = p, .otype = c.otype, .sealed = c.sealed, .tag = c.tag, .epoch = c.epoch, .obj_id = c.obj_id };
}

pub fn seal(c: T.Cap, o: T.OType) T.Cap { return .{ .base = c.base, .len = c.len, .perms = c.perms, .otype = o, .sealed = true, .tag = c.tag, .epoch = c.epoch, .obj_id = c.obj_id }; }
pub fn unseal(c: T.Cap, o: T.OType) ?T.Cap { if (!c.sealed or c.otype != o) return null; var x = c; x.sealed = false; return x; }

pub fn validate(c: *const T.Cap, off: usize, size: usize, need: T.Perms) bool {
    if (!c.tag) return false;
    if (off > c.len or size > c.len or off + size > c.len) return false;
    if (need.R and !c.perms.R) return false;
    if (need.W and !c.perms.W) return false;
    if (need.X and !c.perms.X) return false;
    return true;
}

pub const Serialized = extern struct { base: usize, len: usize, perms: u8, otype: u32, sealed: u8, tag: u8, epoch: u32, obj_id: u64 };

fn packPerms(p: T.Perms) u8 {
    var b: u8 = 0;
    if (p.R) b |= 1;
    if (p.W) b |= 1 << 1;
    if (p.X) b |= 1 << 2;
    if (p.Transfer) b |= 1 << 3;
    if (p.Seal) b |= 1 << 4;
    if (p.Mutate) b |= 1 << 5;
    return b;
}
fn unpackPerms(b: u8) T.Perms {
    return .{ .R = (b & 1) != 0, .W = (b & (1 << 1)) != 0, .X = (b & (1 << 2)) != 0, .Transfer = (b & (1 << 3)) != 0, .Seal = (b & (1 << 4)) != 0, .Mutate = (b & (1 << 5)) != 0 };
}

pub fn serialize(c: *const T.Cap) Serialized { return .{ .base = c.base, .len = c.len, .perms = packPerms(c.perms), .otype = @intFromEnum(c.otype), .sealed = if (c.sealed) 1 else 0, .tag = if (c.tag) 1 else 0, .epoch = c.epoch, .obj_id = c.obj_id }; }
pub fn deserialize(s: *const Serialized) T.Cap { return .{ .base = s.base, .len = s.len, .perms = unpackPerms(s.perms), .otype = @enumFromInt(s.otype), .sealed = s.sealed != 0, .tag = s.tag != 0, .epoch = s.epoch, .obj_id = s.obj_id }; }