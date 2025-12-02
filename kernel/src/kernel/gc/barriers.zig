const api = @import("gc_api");
const card = @import("gc_card");
pub fn write_barrier(obj: [*]u8, new_ptr: [*]u8) void {
    const h = api.header(obj);
    if (h.mark != 0 and new_ptr != null) {
        const nh = api.header(new_ptr);
        nh.mark = 1;
        card.mark(@intFromPtr(new_ptr));
    }
}
