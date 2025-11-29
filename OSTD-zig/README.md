# OSTD-zig (Uya)

- 目标：提供类 OSTD 的底层设施（内存、页表、同步、IO、IRQ）
- 用法：作为 Uya 的内部库按需引入（后续可拆为独立 Zig 包）

目录：
- `src/mem/frame_allocator.zig`
- `src/mm/page_table.zig`
- `src/sync/mutex.zig`
- `src/io/serial.zig`
- `src/irq/idt.zig`