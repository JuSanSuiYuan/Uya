pub const Mutex = struct {
    locked: bool = false,

    pub fn lock(self: *Mutex) void {
        self.locked = true;
    }

    pub fn unlock(self: *Mutex) void {
        self.locked = false;
    }
};

