pub const InitFn = fn() void;
pub const FiniFn = fn() void;
pub const CallFn = fn(id: u64, data: []const u8) usize;
pub const Table = struct { version: u32, init: *const InitFn, fini: *const FiniFn, call: *const CallFn };
pub const ABI_VERSION: u32 = 1;
