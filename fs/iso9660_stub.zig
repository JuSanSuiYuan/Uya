const vfs = @import("fs_vfs");

pub fn mount_system() void {
    _ = vfs.UyaFS.addFile("/system/etc/motd", "欢迎使用 UyaFS\r\n");
    _ = vfs.UyaFS.addFile("/system/etc/version", "UyaFS 0.1\r\n");
    _ = vfs.UyaFS.addAlias("/etc", "/system/etc");
}