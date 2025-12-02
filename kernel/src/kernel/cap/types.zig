pub const Perms = packed struct {
    R: bool = false,
    W: bool = false,
    X: bool = false,
    Transfer: bool = false,
    Seal: bool = false,
    Mutate: bool = false,
};

pub const OType = enum(u32) { Mem, File, Port, ServiceEntry, Process, Thread, Subtree, Leaf };

pub const Cap = struct {
    base: usize = 0,
    len: usize = 0,
    perms: Perms = .{},
    otype: OType = .Mem,
    sealed: bool = false,
    tag: bool = false,
    epoch: u32 = 0,
    obj_id: u64 = 0,
};