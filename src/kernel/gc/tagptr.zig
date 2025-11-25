pub const TaggedPtr = struct { addr: usize, ver: usize };
pub fn init() TaggedPtr { return .{ .addr = 0, .ver = 0 }; }
pub fn load(tp: *TaggedPtr) usize { return tp.addr; }
pub fn store(tp: *TaggedPtr, a: usize) void { tp.addr = a; tp.ver += 1; }
pub fn try_update(tp: *TaggedPtr, expect_addr: usize, expect_ver: usize, new_addr: usize) bool { if (tp.addr == expect_addr and tp.ver == expect_ver) { tp.addr = new_addr; tp.ver += 1; return true; } return false; }
