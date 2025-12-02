const api = @import("win_api");
const h = @import("win_handle");

pub fn dispatch(no: u32, a0: u64, a1: u64) u64 {
    switch (no) {
        1 => {
            const handle: h.Handle = @as(h.Handle, a0);
            return api.GetFileSize(handle);
        },
        2 => {
            const handle: h.Handle = @as(h.Handle, a0);
            return if (api.CloseHandle(handle)) 1 else 0;
        },
        else => { _ = a1; return 0; },
    }
}