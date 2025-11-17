pub const HANDLE = usize;

pub export fn VirtualAlloc(addr: ?usize, size: usize, typ: u32, protect: u32) callconv(.C) ?*anyopaque {
    return null;
}

pub export fn VirtualFree(addr: *anyopaque, size: usize, free_type: u32) callconv(.C) bool {
    return false;
}

pub export fn MapViewOfFile(handle: HANDLE, access: u32, off_high: u32, off_low: u32, size: usize) callconv(.C) ?*anyopaque {
    return null;
}
