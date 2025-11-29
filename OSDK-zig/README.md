# OSDK-zig

- 构建：`powershell -File OSDK-zig/build.ps1`
- 运行：`powershell -File OSDK-zig/run.ps1 -Iso dist\uya.iso`

集成 OSTD-zig：
- 在内核初始化路径调用 `OSTD-zig/src/irq/idt.zig` 的 `load()` 等占位函数
- 在内存管理中引入 `OSTD-zig/src/mem/frame_allocator.zig` 与 `src/mm/page_table.zig`
