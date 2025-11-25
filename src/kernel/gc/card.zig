var base: usize = 0;
var size: usize = 0;
var card_size: usize = 64;
var cards: [4096]u8 = undefined;
var ncards: usize = 0;
pub fn init(heap_base: usize, heap_len: usize, csize: usize) void { base = heap_base; size = heap_len; card_size = csize; ncards = (heap_len + csize - 1) / csize; var i: usize = 0; while (i < cards.len) : (i += 1) cards[i] = 0; }
pub fn mark(addr: usize) void { if (addr < base or addr >= base + size) return; const idx = (addr - base) / card_size; if (idx < cards.len) cards[idx] = 1; }
pub fn is_dirty(idx: usize) bool { if (idx >= ncards) return false; return cards[idx] != 0; }
pub fn ncards_get() usize { return ncards; }
pub fn count_dirty() usize { var c: usize = 0; var i: usize = 0; while (i < ncards) : (i += 1) { if (cards[i] != 0) c += 1; } return c; }
