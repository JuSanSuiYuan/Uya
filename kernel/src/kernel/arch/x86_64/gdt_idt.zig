const IDTEntry = packed struct {
    offset_low: u16,
    selector: u16,
    ist: u8,
    type_attr: u8,
    offset_mid: u16,
    offset_high: u32,
    zero: u32,
};

const IDTR = packed struct { limit: u16, base: usize };

var idt: [256]IDTEntry = undefined;

fn lidt(idtr: *const IDTR) void {
    _ = idtr;
}

pub fn init() void {
    for (&idt) |*e| {
        e.* = .{ .offset_low = 0, .selector = 0, .ist = 0, .type_attr = 0, .offset_mid = 0, .offset_high = 0, .zero = 0 };
    }
    const limit_usize: usize = @sizeOf(@TypeOf(idt)) - 1;
    const idtr = IDTR{ .limit = @as(u16, @intCast(limit_usize)), .base = @intFromPtr(&idt) };
    lidt(&idtr);
}
