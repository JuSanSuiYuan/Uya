const cap_types = @import("cap_types");
const cap_api = @import("cap_api");
const radix = @import("util_radix_tree");

pub const UyaFS = struct {
    pub const DirEntry = struct { name: []const u8, is_dir: bool };

    const Entry = struct { path_buf: [256]u8, path_len: usize, data: []const u8 };
    const Alias = struct { from_buf: [256]u8, from_len: usize, to_buf: [256]u8, to_len: usize };
    var table: [64]Entry = undefined;
    var count: usize = 0;
    var aliases: [16]Alias = undefined;
    var alias_count: usize = 0;

    var rt_nodes: [3][32]radix.Node = undefined;
    var rt_cur: u8 = 0;
    var rt_pending: i8 = -1;
    var rt_pending_epoch: u32 = 0;
    var rt_root: radix.Root = .{ .ptr = &rt_nodes[0][0], .ver = 0 };
    var rt_dir_nodes_a: [32]radix.Node = undefined;
    var rt_dir_nodes_b: [32]radix.Node = undefined;
    var rt_dir_root: radix.Root = .{ .ptr = &rt_dir_nodes_a[0], .ver = 0 };
    var rt_dir_sel: u8 = 0;
    var rt_alias_nodes: [3][32]radix.Node = undefined;
    var rt_alias_cur: u8 = 0;
    var rt_alias_pending: i8 = -1;
    var rt_alias_pending_epoch: u32 = 0;
    var rt_alias_root: radix.Root = .{ .ptr = &rt_alias_nodes[0][0], .ver = 0 };

    fn hash64(data: []const u8) u64 {
        var h: u64 = 1469598103934665603;
        var i: usize = 0;
        while (i < data.len) : (i += 1) {
            h ^= @as(u64, data[i]);
            h *%= 1099511628211;
        }
        return h;
    }

    fn rtMaybeReclaim() void {
        const cap_epoch = @import("cap_epoch");
        if (rt_pending >= 0) {
            if (cap_epoch.is_reclaimable(rt_pending_epoch)) {
                rt_pending = -1;
            }
        }
    }

    fn pickRtTarget() u8 {
        rtMaybeReclaim();
        var t: u8 = (rt_cur + 1) % 3;
        if (rt_pending >= 0 and @as(u8, @intCast(rt_pending)) == t) {
            t = (rt_cur + 2) % 3;
        }
        return t;
    }

    fn rebuildIndex() void {
        const cap_epoch = @import("cap_epoch");
        const target = pickRtTarget();
        var buf: *[32]radix.Node = &rt_nodes[target];
        var bi: usize = 0;
        var ti: usize = 0;
        while (bi < buf.len) : (bi += 1) {
            var j: usize = 0;
            while (j < 16) : (j += 1) { buf.*[bi].keys[j] = 0; buf.*[bi].vals[j] = 0; }
            buf.*[bi].next = null;
        }
        bi = 0;
        while (ti < count) : (ti += 1) {
            const e = table[ti];
            const ep = e.path_buf[0..e.path_len];
            const key = hash64(ep);
            var slot: usize = 0;
            while (slot < 16 and buf.*[bi].keys[slot] != 0) : (slot += 1) {}
            if (slot == 16) {
                if (bi + 1 >= buf.len) break;
                buf.*[bi].next = &buf.*[bi + 1];
                bi += 1;
                slot = 0;
            }
            buf.*[bi].keys[slot] = key;
            buf.*[bi].vals[slot] = ti;
        }
        const publish_epoch = cap_epoch.enter().epoch;
        const new_root = radix.publish(rt_root, &buf.*[0]);
        const prev_cur = rt_cur;
        rt_cur = target;
        rt_root = new_root;
        if (rt_pending < 0) {
            rt_pending = @as(i8, @intCast(prev_cur));
            rt_pending_epoch = publish_epoch;
        } else {
            // if already pending, try reclaim; if still not, keep existing pending
            rtMaybeReclaim();
        }

        var dbuf: *[32]radix.Node = if (rt_dir_sel == 0) &rt_dir_nodes_b else &rt_dir_nodes_a;
        var dbi: usize = 0;
        var di: usize = 0;
        while (dbi < dbuf.len) : (dbi += 1) {
            var j2: usize = 0;
            while (j2 < 16) : (j2 += 1) { dbuf.*[dbi].keys[j2] = 0; dbuf.*[dbi].vals[j2] = 0; }
            dbuf.*[dbi].next = null;
        }
        dbi = 0;
        while (di < count) : (di += 1) {
            const e2 = table[di];
            const ep2 = e2.path_buf[0..e2.path_len];
            var last_slash: ?usize = null;
            var kpos: usize = 0;
            while (kpos < ep2.len) : (kpos += 1) {
                if (ep2[kpos] == '/') last_slash = kpos;
            }
            const parent = if (last_slash) |ls| ep2[0..(if (ls == 0) 1 else ls)] else ep2[0..1];
            const dkey = hash64(parent);
            var present: bool = false;
            var scan: ?*const radix.Node = &dbuf.*[0];
            while (scan) |sn| {
                var s: usize = 0;
                while (s < 16) : (s += 1) {
                    if (sn.keys[s] == dkey) { present = true; break; }
                }
                if (present) break;
                scan = sn.next;
            }
            if (!present) {
                var slot2: usize = 0;
                while (slot2 < 16 and dbuf.*[dbi].keys[slot2] != 0) : (slot2 += 1) {}
                if (slot2 == 16) {
                    if (dbi + 1 >= dbuf.len) break;
                    dbuf.*[dbi].next = &dbuf.*[dbi + 1];
                    dbi += 1;
                    slot2 = 0;
                }
                dbuf.*[dbi].keys[slot2] = dkey;
                dbuf.*[dbi].vals[slot2] = 1;
            }
        }
        rt_dir_root = radix.publish(rt_dir_root, &dbuf.*[0]);
        rt_dir_sel = if (rt_dir_sel == 0) 1 else 0;
    }

    fn aliasMaybeReclaim() void {
        const cap_epoch = @import("cap_epoch");
        if (rt_alias_pending >= 0) {
            if (cap_epoch.is_reclaimable(rt_alias_pending_epoch)) {
                rt_alias_pending = -1;
            }
        }
    }

    fn pickAliasTarget() u8 {
        aliasMaybeReclaim();
        var t: u8 = (rt_alias_cur + 1) % 3;
        if (rt_alias_pending >= 0 and @as(u8, @intCast(rt_alias_pending)) == t) {
            t = (rt_alias_cur + 2) % 3;
        }
        return t;
    }

    fn rebuildAliasIndex() void {
        const cap_epoch = @import("cap_epoch");
        const target = pickAliasTarget();
        var buf: *[32]radix.Node = &rt_alias_nodes[target];
        var bi: usize = 0;
        var ai: usize = 0;
        while (bi < buf.len) : (bi += 1) {
            var j: usize = 0;
            while (j < 16) : (j += 1) { buf.*[bi].keys[j] = 0; buf.*[bi].vals[j] = 0; }
            buf.*[bi].next = null;
        }
        bi = 0;
        while (ai < alias_count) : (ai += 1) {
            const a = aliases[ai];
            const from = a.from_buf[0..a.from_len];
            const key = hash64(from);
            var slot: usize = 0;
            while (slot < 16 and buf.*[bi].keys[slot] != 0) : (slot += 1) {}
            if (slot == 16) {
                if (bi + 1 >= buf.len) break;
                buf.*[bi].next = &buf.*[bi + 1];
                bi += 1;
                slot = 0;
            }
            buf.*[bi].keys[slot] = key;
            buf.*[bi].vals[slot] = ai;
        }
        const publish_epoch = cap_epoch.enter().epoch;
        const new_root = radix.publish(rt_alias_root, &buf.*[0]);
        const prev = rt_alias_cur;
        rt_alias_cur = target;
        rt_alias_root = new_root;
        if (rt_alias_pending < 0) {
            rt_alias_pending = @as(i8, @intCast(prev));
            rt_alias_pending_epoch = publish_epoch;
        } else {
            aliasMaybeReclaim();
        }
    }

    pub fn init() void { count = 0; alias_count = 0; rt_cur = 0; rt_pending = -1; rt_root = .{ .ptr = &rt_nodes[0][0], .ver = 0 }; rt_alias_cur = 0; rt_alias_pending = -1; rt_alias_root = .{ .ptr = &rt_alias_nodes[0][0], .ver = 0 }; rebuildIndex(); rebuildAliasIndex(); }

    pub fn addFile(path: []const u8, data: []const u8) bool {
        var norm: [256]u8 = undefined;
        const nlen_opt = normalize(path, norm[0..]);
        if (nlen_opt == null) return false;
        const nlen = nlen_opt.?;
        if (count >= table.len) return false;
        var e = &table[count];
        var i: usize = 0;
        while (i < nlen) : (i += 1) e.path_buf[i] = norm[i];
        e.path_len = nlen;
        e.data = data;
        count += 1;
        rebuildIndex();
        return true;
    }

    pub fn read(path: []const u8) ?[]const u8 {
        const cap_epoch = @import("cap_epoch");
        const tok = cap_epoch.enter();
        defer cap_epoch.exit(tok);
        var norm: [256]u8 = undefined;
        const nlen_opt = normalize(path, norm[0..]);
        if (nlen_opt == null) return null;
        var nlen = nlen_opt.?;
        var res: [256]u8 = undefined;
        if (resolveAlias(norm[0..nlen], &res, &nlen)) {
            var i: usize = 0;
            while (i < nlen) : (i += 1) norm[i] = res[i];
        }
        if (isRevoked(norm[0..nlen])) return null;
        const key = hash64(norm[0..nlen]);
        if (radix.lookup(rt_root.ptr, key)) |idx| {
            const e = table[idx];
            const ep = e.path_buf[0..e.path_len];
            if (sliceEq(norm[0..nlen], ep)) return e.data;
        } else {
            var i: usize = 0;
            while (i < count) : (i += 1) {
                const e = table[i];
                const ep = e.path_buf[0..e.path_len];
                if (sliceEq(norm[0..nlen], ep)) return e.data;
            }
        }
        return null;
    }

    fn findIndex(path: []const u8) ?usize {
        var norm: [256]u8 = undefined;
        const nlen_opt = normalize(path, norm[0..]);
        if (nlen_opt == null) return null;
        const nlen = nlen_opt.?;
        if (isRevoked(norm[0..nlen])) return null;
        const key = hash64(norm[0..nlen]);
        if (radix.lookup(rt_root.ptr, key)) |idx| {
            const e = table[idx];
            const ep = e.path_buf[0..e.path_len];
            if (sliceEq(norm[0..nlen], ep)) return idx;
        } else {
            var i: usize = 0;
            while (i < count) : (i += 1) {
                const e = table[i];
                const ep = e.path_buf[0..e.path_len];
                if (sliceEq(norm[0..nlen], ep)) return i;
            }
        }
        return null;
    }

    pub fn openCap(path: []const u8) ?cap_types.Cap {
        const idx = findIndex(path) orelse return null;
        const sz = size(path) orelse 0;
        const perms: cap_types.Perms = .{ .R = true, .W = true };
        return .{ .base = 0, .len = sz, .perms = perms, .otype = .File, .sealed = false, .tag = true, .epoch = rt_root.ver, .obj_id = @as(u64, @intCast(idx)) };
    }

    pub fn openSubtreeCap(prefix: []const u8) ?cap_types.Cap {
        var norm: [256]u8 = undefined;
        const plen = normalize(prefix, norm[0..]) orelse return null;
        const key = hash64(norm[0..plen]);
        const perms: cap_types.Perms = .{ .R = true, .W = true, .Transfer = true };
        return .{ .base = @as(usize, plen), .len = 0, .perms = perms, .otype = .Subtree, .sealed = false, .tag = true, .epoch = rt_root.ver, .obj_id = key };
    }

    pub fn openLeafCap(path: []const u8) ?cap_types.Cap {
        const idx = findIndex(path) orelse return null;
        const sz = size(path) orelse 0;
        const perms: cap_types.Perms = .{ .R = true, .W = true };
        return .{ .base = 0, .len = sz, .perms = perms, .otype = .Leaf, .sealed = false, .tag = true, .epoch = rt_root.ver, .obj_id = @as(u64, @intCast(idx)) };
    }

    fn authorizePathBySubtree(c: *const cap_types.Cap, path: []const u8) bool {
        if (c.otype != .Subtree) return false;
        var norm: [256]u8 = undefined;
        const nlen = normalize(path, norm[0..]) orelse return false;
        const need_len = c.base;
        if (need_len > nlen) return false;
        const part = norm[0..need_len];
        const h = hash64(part);
        return h == c.obj_id;
    }

    pub fn openLeafWithSubtree(c: *const cap_types.Cap, path: []const u8) ?cap_types.Cap {
        if (c.epoch != rt_root.ver) return null;
        if (!authorizePathBySubtree(c, path)) return null;
        return openLeafCap(path);
    }

    // Subtree revocation: record revoked prefixes; rebuild LRT and defer reuse via Epoch
    var revoked_keys: [16]u64 = [_]u64{0} ** 16;
    var revoked_lens: [16]usize = [_]usize{0} ** 16;
    var revoked_len: usize = 0;

    fn isRevoked(path: []const u8) bool {
        var i: usize = 0;
        while (i < revoked_len) : (i += 1) {
            const plen = revoked_lens[i];
            if (plen == 0 or plen > path.len) continue;
            if (prefixEq(path, path[0..plen])) { // trivially true
                const h = hash64(path[0..plen]);
                if (h == revoked_keys[i]) return true;
            }
        }
        return false;
    }

    pub fn revokeSubtree(prefix: []const u8) bool {
        var norm: [256]u8 = undefined;
        const plen = normalize(prefix, norm[0..]) orelse return false;
        if (revoked_len >= revoked_keys.len) return false;
        revoked_keys[revoked_len] = hash64(norm[0..plen]);
        revoked_lens[revoked_len] = plen;
        revoked_len += 1;
        rebuildIndex();
        rebuildAliasIndex();
        return true;
    }

    pub fn readCap(c: *const cap_types.Cap, off: usize, len: usize) ?[]const u8 {
        const cap_epoch = @import("cap_epoch");
        const tok = cap_epoch.enter();
        defer cap_epoch.exit(tok);
        const need: cap_types.Perms = .{ .R = true };
        if (c.otype == .Leaf or c.otype == .File) {
            if (c.epoch != rt_root.ver) return null;
        }
        if (!cap_api.validate(c, off, len, need)) return null;
        const idx = @as(usize, @intCast(c.obj_id));
        if (idx >= count) return null;
        const e = table[idx];
        if (off + len > e.data.len) return null;
        return e.data[off .. off + len];
    }

    pub fn exists(path: []const u8) bool {
        return read(path) != null;
    }

    pub fn isDir(path: []const u8) bool {
        var norm: [256]u8 = undefined;
        const nlen_opt = normalize(path, norm[0..]);
        if (nlen_opt == null) return false;
        var base_len: usize = nlen_opt.?;
        if (!(base_len == 1 and norm[0] == '/')) {
            if (norm[base_len - 1] == '/') base_len -= 1;
        }
        const key = hash64(norm[0..base_len]);
        return radix.lookup(rt_dir_root.ptr, key) != null;
    }

    pub fn size(path: []const u8) ?usize {
        var norm: [256]u8 = undefined;
        const nlen_opt = normalize(path, norm[0..]);
        if (nlen_opt == null) return null;
        const nlen = nlen_opt.?;
        var i: usize = 0;
        while (i < count) : (i += 1) {
            const e = table[i];
            const ep = e.path_buf[0..e.path_len];
            if (sliceEq(norm[0..nlen], ep)) return e.data.len;
        }
        return null;
    }

    // directory listing optimized by prebuilt chain indices
    var dir_heads_keys: [64]u64 = [_]u64{0} ** 64;
    var dir_heads_vals: [64]i32 = [_]i32{-1} ** 64;
    var dir_heads_len: usize = 0;
    var dir_next: [64]i32 = [_]i32{-1} ** 64;

    fn dirHeadsReset() void {
        dir_heads_len = 0;
        var i: usize = 0;
        while (i < dir_next.len) : (i += 1) dir_next[i] = -1;
    }

    fn dirHeadsFindOrAdd(key: u64) usize {
        var i: usize = 0;
        while (i < dir_heads_len) : (i += 1) if (dir_heads_keys[i] == key) return i;
        if (dir_heads_len < dir_heads_keys.len) {
            const pos = dir_heads_len;
            dir_heads_len += 1;
            dir_heads_keys[pos] = key;
            dir_heads_vals[pos] = -1;
            return pos;
        }
        return 0;
    }

    pub fn list(dir: []const u8, out: []DirEntry) usize {
        var norm: [256]u8 = undefined;
        const nlen_opt = normalize(dir, norm[0..]);
        if (nlen_opt == null) return 0;
        var base_len: usize = nlen_opt.?;
        var res: [256]u8 = undefined;
        var res_len: usize = base_len;
        if (resolveAlias(norm[0..base_len], &res, &res_len)) {
            var i: usize = 0;
            while (i < res_len) : (i += 1) norm[i] = res[i];
            base_len = res_len;
        }
        if (!(base_len == 1 and norm[0] == '/')) {
            if (norm[base_len - 1] == '/') base_len -= 1;
        }
        const dkey = hash64(norm[0..base_len]);
        // build dir heads from table
        dirHeadsReset();
        var i: usize = 0;
        while (i < count) : (i += 1) {
            const e = table[i];
            const ep = e.path_buf[0..e.path_len];
            var last_slash: ?usize = null;
            var kpos: usize = 0;
            while (kpos < ep.len) : (kpos += 1) {
                if (ep[kpos] == '/') last_slash = kpos;
            }
            const parent = if (last_slash) |ls| ep[0..(if (ls == 0) 1 else ls)] else ep[0..1];
            const pkey = hash64(parent);
            const pos = dirHeadsFindOrAdd(pkey);
            const old = dir_heads_vals[pos];
            dir_heads_vals[pos] = @as(i32, @intCast(i));
            dir_next[i] = old;
        }
        // enumerate from head chain for this directory
        var written: usize = 0;
        var head_idx: ?i32 = null;
        var h: usize = 0;
        while (h < dir_heads_len) : (h += 1) {
            if (dir_heads_keys[h] == dkey) { head_idx = dir_heads_vals[h]; break; }
        }
        if (head_idx) |hi| {
            var cur = hi;
            while (cur != -1) {
                const e = table[@as(usize, @intCast(cur))];
                const ep = e.path_buf[0..e.path_len];
                if (prefixEq(ep, norm[0..base_len])) {
                    var rem_start: usize = base_len;
                    if (!(base_len == 1 and norm[0] == '/')) {
                        if (rem_start < ep.len and ep[rem_start] == '/') rem_start += 1;
                    }
                    if (rem_start < ep.len) {
                        var j: usize = rem_start;
                        while (j < ep.len and ep[j] != '/') : (j += 1) {}
                        const name = ep[rem_start..j];
                        var is_dir = false;
                        if (j < ep.len and ep[j] == '/') is_dir = true;
                        var found: bool = false;
                        var k: usize = 0;
                        while (k < written) : (k += 1) { if (sliceEq(out[k].name, name)) { found = true; break; } }
                        if (!found and written < out.len) {
                            out[written] = .{ .name = name, .is_dir = is_dir };
                            written += 1;
                        }
                    }
                }
                cur = dir_next[@as(usize, @intCast(cur))];
            }
        }
        return written;
    }

    pub fn addAlias(from: []const u8, to: []const u8) bool {
        var nf: [256]u8 = undefined;
        var nt: [256]u8 = undefined;
        const fl = normalize(from, nf[0..]) orelse return false;
        const tl = normalize(to, nt[0..]) orelse return false;
        if (alias_count >= aliases.len) return false;
        var a = &aliases[alias_count];
        var i: usize = 0;
        while (i < fl) : (i += 1) a.from_buf[i] = nf[i];
        a.from_len = fl;
        i = 0;
        while (i < tl) : (i += 1) a.to_buf[i] = nt[i];
        a.to_len = tl;
        alias_count += 1;
        rebuildAliasIndex();
        return true;
    }

    fn resolveAlias(path: []const u8, out: *[256]u8, out_len: *usize) bool {
        var end: usize = path.len;
        while (end > 0) {
            var pos: isize = @as(isize, @intCast(end - 1));
            while (pos > 0 and path[@as(usize, @intCast(pos))] != '/') : (pos -= 1) {}
            const pre_len: usize = @as(usize, @intCast(if (pos <= 0) 1 else pos));
            const key = hash64(path[0..pre_len]);
            if (radix.lookup(rt_alias_root.ptr, key)) |ai| {
                const a = aliases[ai];
                const from = a.from_buf[0..a.from_len];
                if (prefixEq(path, from)) {
                    var len: usize = 0;
                    var k: usize = 0;
                    while (k < a.to_len) : (k += 1) { out.*[len] = a.to_buf[k]; len += 1; }
                    if (from.len < path.len) {
                        if (!(len == 1 and out.*[0] == '/')) { out.*[len] = '/'; len += 1; }
                        var p: usize = from.len;
                        if (!(from.len == 1 and from[0] == '/')) { if (p < path.len and path[p] == '/') p += 1; }
                        while (p < path.len) : (p += 1) { out.*[len] = path[p]; len += 1; }
                    }
                    out_len.* = len;
                    return true;
                }
            }
            if (pre_len == 1) break;
            end = pre_len;
        }
        return false;
    }

    fn sliceEq(a: []const u8, b: []const u8) bool {
        if (a.len != b.len) return false;
        var i: usize = 0;
        while (i < a.len) : (i += 1) {
            const ca = foldLower(a[i]);
            const cb = foldLower(b[i]);
            if (ca != cb) return false;
        }
        return true;
    }

    fn prefixEq(a: []const u8, pre: []const u8) bool {
        if (pre.len > a.len) return false;
        var i: usize = 0;
        while (i < pre.len) : (i += 1) {
            const ca = foldLower(a[i]);
            const cb = foldLower(pre[i]);
            if (ca != cb) return false;
        }
        return true;
    }

    fn normalize(path: []const u8, out: []u8) ?usize {
        if (path.len == 0 or path[0] != '/') return null;
        var out_len: usize = 0;
        out[out_len] = '/';
        out_len += 1;
        var i: usize = 1;
        while (i < path.len) {
            while (i < path.len and (path[i] == '/' or path[i] == '\\')) : (i += 1) {}
            if (i >= path.len) break;
            const start = i;
            while (i < path.len and (path[i] != '/' and path[i] != '\\')) : (i += 1) {}
            const comp = path[start..i];
            if (comp.len == 0) continue;
            if (comp.len == 1 and comp[0] == '.') continue;
            if (comp.len == 2 and comp[0] == '.' and comp[1] == '.') {
                if (out_len > 1) {
                    while (out_len > 1 and out[out_len - 1] != '/') : (out_len -= 1) {}
                    if (out_len > 1) out_len -= 1;
                }
                continue;
            }
            if (out_len > 1) {
                if (out_len >= out.len) return null;
                out[out_len] = '/';
                out_len += 1;
            }
            var k: usize = 0;
            while (k < comp.len) : (k += 1) {
                if (out_len >= out.len) return null;
                const ch = comp[k];
                out[out_len] = if (ch >= 'A' and ch <= 'Z') ch + 32 else ch;
                out_len += 1;
            }
        }
        return out_len;
    }

    fn foldLower(c: u8) u8 { return if (c >= 'A' and c <= 'Z') c + 32 else c; }
};