pub const PTE = struct {
    phys: usize,
    valid: bool,
    writable: bool,
};

pub fn init() void {}

pub fn map(virt: usize, phys: usize, writable: bool) bool {
    _ = virt; _ = phys; _ = writable;
    return true;
}

pub fn unmap(virt: usize) bool {
    _ = virt;
    return true;
}

