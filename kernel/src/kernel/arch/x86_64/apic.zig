pub var lapic_ready: bool = false;
pub var ioapic_ready: bool = false;
pub var timer_ready: bool = false;

pub fn lapic_init() void { lapic_ready = true; }
pub fn ioapic_init() void { ioapic_ready = true; }
pub fn timer_init() void { timer_ready = true; }
pub var lapic_ids: [64]u32 = undefined;
pub var lapic_id_count: usize = 0;
pub fn set_lapic_ids(ids: []const u32) void {
    lapic_id_count = if (ids.len > 64) 64 else ids.len;
    var i: usize = 0;
    while (i < lapic_id_count) : (i += 1) lapic_ids[i] = ids[i];
}
pub var lapic_base: usize = 0;
pub fn set_lapic_base(addr: usize) void { lapic_base = addr; }

pub const IoApic = struct { id: u8, address: u32, gsi_base: u32 };
pub var ioapics: [8]IoApic = undefined;
pub var ioapic_count: usize = 0;
pub fn add_ioapic(id: u8, address: u32, gsi_base: u32) void {
    if (ioapic_count < ioapics.len) {
        ioapics[ioapic_count] = .{ .id = id, .address = address, .gsi_base = gsi_base };
        ioapic_count += 1;
    }
}

pub const Iso = struct { bus: u8, source: u8, gsi: u32, flags: u16 };
pub var isos: [32]Iso = undefined;
pub var iso_count: usize = 0;
pub fn add_iso(bus: u8, source: u8, gsi: u32, flags: u16) void {
    if (iso_count < isos.len) {
        isos[iso_count] = .{ .bus = bus, .source = source, .gsi = gsi, .flags = flags };
        iso_count += 1;
    }
}
pub const Route = struct { ioapic_index: usize, gsi: u32, vector: u8, flags: u16 };
pub var routes: [64]Route = undefined;
pub var route_count: usize = 0;
fn pick_ioapic(gsi: u32) ?usize {
    if (ioapic_count == 0) return null;
    var best: ?usize = null;
    var i: usize = 0;
    while (i < ioapic_count) : (i += 1) {
        if (gsi >= ioapics[i].gsi_base) best = i;
    }
    return best;
}
pub fn route_irq(gsi: u32, vector: u8, flags: u16) bool {
    const idx_opt = pick_ioapic(gsi);
    if (idx_opt == null) return false;
    const idx: usize = idx_opt.?;
    if (route_count < routes.len) {
        routes[route_count] = .{ .ioapic_index = idx, .gsi = gsi, .vector = vector, .flags = flags };
        route_count += 1;
        return true;
    }
    return false;
}
pub fn build_initial_routes() void {
    var i: usize = 0;
    while (i < iso_count) : (i += 1) {
        const v: u8 = @as(u8, @intCast(0x20 + isos[i].source));
        _ = route_irq(isos[i].gsi, v, isos[i].flags);
    }
}
fn ioapic_write(address: u32, reg: u32, value: u32) void {
    const idx: *volatile u32 = @as(*volatile u32, @ptrFromInt(@as(usize, address)));
    const dat: *volatile u32 = @as(*volatile u32, @ptrFromInt(@as(usize, address) + 0x10));
    idx.* = reg;
    dat.* = value;
}
fn ioapic_program_redir(io_idx: usize, entry: u32, vector: u8, flags: u16, dest_apic_id: u32) void {
    const base = ioapics[io_idx].address;
    const pol_low = (flags & 0x02) != 0;
    const trg_lvl = (flags & 0x08) != 0;
    var lo: u32 = @as(u32, vector);
    if (pol_low) lo |= (1 << 13);
    if (trg_lvl) lo |= (1 << 15);
    const hi: u32 = dest_apic_id << 24;
    ioapic_write(base, 0x10 + entry * 2, lo);
    ioapic_write(base, 0x10 + entry * 2 + 1, hi);
}
pub fn apply_routes() void {
    var i: usize = 0;
    while (i < route_count) : (i += 1) {
        const r = routes[i];
        const io = ioapics[r.ioapic_index];
        const entry = r.gsi - io.gsi_base;
        const dest: u32 = if (lapic_id_count > 0) lapic_ids[0] else 0;
        ioapic_program_redir(r.ioapic_index, entry, r.vector, r.flags, dest);
    }
}
pub fn timer_enable(core_id: u32) void { _ = core_id; timer_ready = true; }
pub fn timer_tick(core_id: u32) void {
    const cid: usize = @as(usize, @intCast(core_id));
    percpu.tick(cid);
    const cap_epoch = @import("cap_epoch");
    cap_epoch.advance_all_cores();
}
const percpu = @import("percpu.zig");
fn lapic_write(offset: usize, value: u32) void {
    const reg: *volatile u32 = @as(*volatile u32, @ptrFromInt(lapic_base + offset));
    reg.* = value;
}
fn lapic_read(offset: usize) u32 {
    const reg: *volatile u32 = @as(*volatile u32, @ptrFromInt(lapic_base + offset));
    return reg.*;
}
pub fn timer_config(vector: u8, initial_count: u32, divide: u32) void {
    _ = lapic_read(0x20);
    lapic_write(0x3E0, divide);
    lapic_write(0x320, 0x00000000 | @as(u32, vector));
    lapic_write(0x380, initial_count);
}