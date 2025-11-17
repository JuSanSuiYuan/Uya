const apic = @import("apic.zig");

pub var rsdp_found: bool = false;
var madt_addr: usize = 0;
var madt_len: usize = 0;
var lapic_ids: [64]u32 = undefined;
var lapic_id_count: usize = 0;

pub fn init() void { rsdp_found = false; madt_addr = 0; madt_len = 0; lapic_id_count = 0; }

pub const SdtHeader = extern struct {
    signature: [4]u8,
    length: u32,
    revision: u8,
    checksum: u8,
    oem_id: [6]u8,
    oem_table_id: [8]u8,
    oem_revision: u32,
    creator_id: u32,
    creator_revision: u32,
};

pub const MadtFields = extern struct { lapic_addr: u32, flags: u32 };
pub const MadtLocalApic = extern struct { typ: u8, len: u8, acpi_id: u8, apic_id: u8, flags: u32 };
pub const MadtX2Apic = extern struct { typ: u8, len: u8, reserved: u16, apic_id: u32, flags: u32, acpi_id: u32 };
pub const MadtIoApic = extern struct { typ: u8, len: u8, id: u8, reserved: u8, addr: u32, gsi_base: u32 };
pub const MadtIso = extern struct { typ: u8, len: u8, bus: u8, source: u8, gsi: u32, flags: u16 };
pub const MadtLapicAddrOverride = extern struct { typ: u8, len: u8, reserved: u16, addr: u64 };

pub fn set_madt(addr: usize, len: usize) void { madt_addr = addr; madt_len = len; }

pub fn parse_madt_lapic_ids() usize {
    if (madt_addr == 0 or madt_len == 0) return 0;
    const hdr: *SdtHeader = @as(*SdtHeader, @ptrFromInt(madt_addr));
    const total: usize = @as(usize, @intCast(hdr.length));
    const base: usize = madt_addr + @sizeOf(SdtHeader) + @sizeOf(MadtFields);
    var off: usize = 0;
    var cnt: usize = 0;
    while (off + 2 <= total and cnt < lapic_ids.len) : (off += @as(usize, entry_len(@as(*const u8, @ptrFromInt(base + off))))) {
        const typ = entry_type(@as(*const u8, @ptrFromInt(base + off)));
        if (typ == 0 and off + 8 <= total) {
            const e: *MadtLocalApic = @as(*MadtLocalApic, @ptrFromInt(base + off));
            if ((e.flags & 0x1) != 0) { lapic_ids[cnt] = e.apic_id; cnt += 1; }
        } else if (typ == 9 and off + 16 <= total) {
            const e9: *MadtX2Apic = @as(*MadtX2Apic, @ptrFromInt(base + off));
            if ((e9.flags & 0x1) != 0) { lapic_ids[cnt] = @as(u32, @intCast(e9.apic_id)); cnt += 1; }
        }
        if (entry_len(@as(*const u8, @ptrFromInt(base + off))) == 0) break;
    }
    lapic_id_count = cnt;
    return cnt;
}

fn entry_type(p: *const u8) u8 { return p.*; }
fn entry_len(p: *const u8) u8 { return (@as(*const u8, @ptrFromInt(@intFromPtr(p) + 1))).*; }

pub fn register_to_apic() void {
    if (lapic_id_count == 0) return;
    apic.set_lapic_ids(lapic_ids[0..lapic_id_count]);
}

const RSDP = extern struct {
    signature: [8]u8,
    checksum: u8,
    oemid: [6]u8,
    revision: u8,
    rsdt_addr: u32,
    length: u32,
    xsdt_addr: u64,
    ext_checksum: u8,
    reserved: [3]u8,
};

pub fn find_madt_from_rsdp(rsdp_ptr: usize) ?struct { addr: usize, len: usize } {
    if (rsdp_ptr == 0) return null;
    const rsdp: *RSDP = @as(*RSDP, @ptrFromInt(rsdp_ptr));
    const use_xsdt: bool = rsdp.revision >= 2 and rsdp.xsdt_addr != 0;
    const tbl_addr: usize = if (use_xsdt) @as(usize, @intCast(rsdp.xsdt_addr)) else @as(usize, rsdp.rsdt_addr);
    const hdr: *SdtHeader = @as(*SdtHeader, @ptrFromInt(tbl_addr));
    const total: usize = hdr.length;
    const entry_size: usize = if (use_xsdt) 8 else 4;
    const entry_base: usize = tbl_addr + @sizeOf(SdtHeader);
    const count: usize = (total - @sizeOf(SdtHeader)) / entry_size;
    var i: usize = 0;
    while (i < count) : (i += 1) {
        const ent_addr: usize = if (use_xsdt)
            @as(usize, @intCast((@as(*const u64, @ptrFromInt(entry_base + i * 8)).*)) )
            else @as(usize, (@as(*const u32, @ptrFromInt(entry_base + i * 4)).*));
        const th: *SdtHeader = @as(*SdtHeader, @ptrFromInt(ent_addr));
        if (th.signature[0] == 'A' and th.signature[1] == 'P' and th.signature[2] == 'I' and th.signature[3] == 'C') {
            return .{ .addr = ent_addr, .len = th.length };
        }
    }
    return null;
}

pub fn parse_madt_platform() void {
    if (madt_addr == 0 or madt_len == 0) return;
    const hdr: *SdtHeader = @as(*SdtHeader, @ptrFromInt(madt_addr));
    const total: usize = @as(usize, @intCast(hdr.length));
    const fields: *MadtFields = @as(*MadtFields, @ptrFromInt(madt_addr + @sizeOf(SdtHeader)));
    apic.set_lapic_base(@as(usize, fields.lapic_addr));
    const base: usize = madt_addr + @sizeOf(SdtHeader) + @sizeOf(MadtFields);
    var off: usize = 0;
    while (off + 2 <= total) : (off += @as(usize, entry_len(@as(*const u8, @ptrFromInt(base + off))))) {
        const typ = entry_type(@as(*const u8, @ptrFromInt(base + off)));
        if (typ == 1 and off + 12 <= total) {
            const io: *MadtIoApic = @as(*MadtIoApic, @ptrFromInt(base + off));
            apic.add_ioapic(io.id, io.addr, io.gsi_base);
        } else if (typ == 2 and off + 10 <= total) {
            const so: *MadtIso = @as(*MadtIso, @ptrFromInt(base + off));
            apic.add_iso(so.bus, so.source, so.gsi, so.flags);
        } else if (typ == 5 and off + 12 <= total) {
            const ov: *MadtLapicAddrOverride = @as(*MadtLapicAddrOverride, @ptrFromInt(base + off));
            apic.set_lapic_base(@as(usize, @intCast(ov.addr)));
        }
        if (entry_len(@as(*const u8, @ptrFromInt(base + off))) == 0) break;
    }
}