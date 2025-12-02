pub const Context = struct {
    rip: u64,
    rsp: u64,
    rflags: u64,
};

pub fn init(entry: u64, sp: u64) Context {
    return .{ .rip = entry, .rsp = sp, .rflags = 0x202 };
}

pub fn run(ctx: *Context) void {
    _ = ctx;
}