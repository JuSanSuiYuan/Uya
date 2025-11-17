const fs = @import("fs_vfs");

pub fn write(path: []const u8, data: []const u8) bool {
    _ = fs.UyaFS.addFile(path, data);
    return true;
}

pub fn exit(code: u32) noreturn {
    while (true) { _ = code; }
}