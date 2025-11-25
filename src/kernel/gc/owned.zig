const std = @import("std");
const gc = @import("gc_api");
const bar = @import("gc_bar");
const cap_epoch = @import("cap_epoch");

pub fn Owned(comptime T: type, comptime OwnerTag: type) type {
    return struct {
        ptr: *T,
        ot: OwnerTag,
        alive: bool,
        mut_active: bool,

        pub fn init() ?@This() {
            const p = gc.alloc(@sizeOf(T)) orelse return null;
            const tp: *T = @ptrCast(@alignCast(p));
            return .{ .ptr = tp, .ot = undefined, .alive = true, .mut_active = false };
        }

        pub fn drop(self: *@This()) void {
            if (!self.alive) return;
            self.alive = false;
        }

        pub fn move_to(self: *@This(), comptime NewOwnerTag: type) Owned(T, NewOwnerTag) {
            if (!self.alive) @compileError("move after drop");
            const out: Owned(T, NewOwnerTag) = .{ .ptr = self.ptr, .ot = undefined, .alive = true, .mut_active = self.mut_active };
            self.alive = false;
            return out;
        }

        pub fn borrow(self: *@This(), comptime LifetimeTag: type) Borrow(T, LifetimeTag) {
            if (!self.alive) @compileError("borrow after drop");
            gc.register_root(@ptrCast([*]u8, self.ptr), @sizeOf(T));
            return .{ .ptr = self.ptr, .lt: LifetimeTag = undefined };
        }

        pub fn borrow_mut(self: *@This(), comptime LifetimeTag: type) BorrowMut(T, LifetimeTag) {
            if (!self.alive) @compileError("borrow after drop");
            if (self.mut_active) @compileError("second mutable borrow");
            gc.register_root(@ptrCast([*]u8, self.ptr), @sizeOf(T));
            self.mut_active = true;
            return .{ .ptr = self.ptr, .lt: LifetimeTag = undefined, .owner_ptr = self.ptr, .owner_state = self };
        }
    };
}

pub fn Borrow(comptime T: type, comptime LifetimeTag: type) type {
    return struct {
        ptr: *const T,
        lt: LifetimeTag,
        pub fn end(self: *@This()) void { gc.unregister_root(@ptrCast([*]u8, self.ptr)); }
    };
}

pub fn BorrowMut(comptime T: type, comptime LifetimeTag: type) type {
    return struct {
        ptr: *T,
        lt: LifetimeTag,
        owner_ptr: *T,
        owner_state: *Owned(T, anytype),
        pub fn write(self: *@This(), f: fn(*T) void) void { f(self.ptr); bar.write_barrier(@ptrCast([*]u8, self.ptr), @ptrCast([*]u8, self.ptr)); }
        pub fn end(self: *@This()) void { gc.unregister_root(@ptrCast([*]u8, self.ptr)); self.owner_state.mut_active = false; }
    };
}

pub fn with_epoch(comptime LifetimeTag: type, body: fn(LifetimeTag) void) void {
    const tok = cap_epoch.enter();
    body(undefined);
    cap_epoch.exit(tok);
}

pub fn with_borrow(comptime T: type, comptime LifetimeTag: type, b: Borrow(T, LifetimeTag), body: fn(Borrow(T, LifetimeTag)) void) void {
    with_epoch(LifetimeTag, struct { fn run(_: LifetimeTag) void { body(b); } }.run);
    var x = b; x.end();
}
pub fn with_borrow_mut(comptime T: type, comptime LifetimeTag: type, bm: BorrowMut(T, LifetimeTag), body: fn(BorrowMut(T, LifetimeTag)) void) void {
    with_epoch(LifetimeTag, struct { fn run(_: LifetimeTag) void { body(bm); } }.run);
    var y = bm; y.end();
}
