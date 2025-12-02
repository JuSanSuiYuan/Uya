const serial = @import("../src/kernel/arch/x86_64/serial.zig");

pub const Prot = enum(u32) { r, w, x };
pub const Fault = enum(u32) { access, not_present, write };

pub fn mm_map(proc: *anyopaque, va: usize, pa: usize, len: usize, prot: Prot) !void {
    _ = proc;
    _ = va;
    _ = pa;
    _ = len;
    _ = prot;
    serial.writeStr("mm_map\r\n");
}
pub fn mm_unmap(proc: *anyopaque, va: usize, len: usize) !void {
    _ = proc;
    _ = va;
    _ = len;
    serial.writeStr("mm_unmap\r\n");
}
pub fn mm_protect(proc: *anyopaque, va: usize, len: usize, prot: Prot) !void {
    _ = proc;
    _ = prot;
    _ = va;
    _ = len;
    _ = prot;
    serial.writeStr("mm_protect\r\n");
}
pub fn mm_fault(proc: *anyopaque, va: usize, reason: Fault) !void {
    _ = proc;
    _ = va;
    _ = reason;
    serial.writeStr("mm_fault\r\n");
}
