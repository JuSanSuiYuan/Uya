pub const Order = enum { relaxed, acquire, release, acqrel, seqcst };
pub fn loadUsize(ptr: *volatile usize) usize { return ptr.*; }
pub fn storeUsize(ptr: *volatile usize, v: usize) void { ptr.* = v; }
pub fn loadU32(ptr: *volatile u32) u32 { return ptr.*; }
pub fn storeU32(ptr: *volatile u32, v: u32) void { ptr.* = v; }
pub fn loadI32(ptr: *volatile i32) i32 { return ptr.*; }
pub fn storeI32(ptr: *volatile i32, v: i32) void { ptr.* = v; }
pub fn casI32(ptr: *volatile i32, expected: i32, desired: i32) bool {
    if (ptr.* == expected) { ptr.* = desired; return true; }
    return false;
}
pub fn loadU64(ptr: *volatile u64) u64 { return ptr.*; }
pub fn storeU64(ptr: *volatile u64, v: u64) void { ptr.* = v; }
pub fn casU64(ptr: *volatile u64, expected: u64, desired: u64) bool {
    if (ptr.* == expected) { ptr.* = desired; return true; }
    return false;
}