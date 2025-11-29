pub const Frame = struct {
    addr: usize,
};

pub fn init() void {}

pub fn alloc() ?Frame {
    return null;
}

pub fn free(f: Frame) void {
    _ = f;
}

