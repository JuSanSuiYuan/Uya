pub const Persona = enum { win64, linux, bsd };
const win_sc = @import("win_syscall");
const lnx_sc = @import("abi_linux");
const bsd_sc = @import("abi_bsd");

pub fn dispatch(p: Persona, no: u32, a0: u64, a1: u64) u64 {
    return switch (p) {
        .win64 => win_sc.dispatch(no, a0, a1),
        .linux => lnx_sc.dispatch(no, a0, a1),
        .bsd => bsd_sc.dispatch(no, a0, a1),
    };
}