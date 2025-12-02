pub const Sys = enum(u32) { write = 1, exit = 2, time = 3, open = 4, read = 5 };
const fs = @import("fs_vfs");
const persona = @import("abi_persona");

pub fn dispatch(nr: u32, a1: usize, a2: usize) usize {
    const code: Sys = @enumFromInt(nr);
    switch (code) {
        .write => {
            _ = fs.UyaFS.addFile("/var/log/sys", "w");
            return 0;
        },
        .exit => {
            _ = a1; while (true) {}
        },
        .time => { return 0; },
        .open => { _ = a1; return 0; },
        .read => { _ = a2; return 0; },
    }
}