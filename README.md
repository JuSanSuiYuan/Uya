# Uya 优雅系统

Uya 是一个以 Zig 编写的实验性“内核 + 桌面环境”工程，目标是在可控的现代架构上探索：能力化（Capabilities）、无锁并发结构、侵入式链表、多核消息队列，以及跨人格（Win/Linux/BSD）最小系统调用桥接。

- 许可证：Mulan PSL v2（木兰宽松许可证，第2版）
- 支持平台：x86_64（内核），Windows（主机侧工具/桌面原型）
- 引导方式：Limine BIOS El Torito（默认）

## 目录结构
- `src/`：内核源码（Zig）
- `mm/`：内存管理（映射/保护/缺页索引）
- `fs/`：内置 `UyaFS`、FAT32 示例、ISO stub
- `apps/uyade/`：桌面环境原型与组件
- `apps/registry/`：注册表 CLI/服务与工作树实现
- `scripts/`：构建、打包 ISO、运行 QEMU 的脚本
- `limine/`：`limine.cfg`
- `third_party/limine/`：Limine 运行时二进制（需准备）

## 快速开始（Windows 11）
1. 安装依赖：`Zig`、`QEMU`；ISO 生成工具优先 `xorriso`，也可 `genisoimage/mkisofs` 或通过 `WSL` 调用 `xorriso`
2. 准备 Limine 二进制：将 `limine-bios-cd.bin` 复制为 `third_party/limine/limine-cd.bin`，并放置 `third_party/limine/limine-bios.sys`（或 `limine.sys`）
3. 构建与运行：
   - `zig build`
   - `scripts\make_iso.ps1`
   - `scripts\qemu.ps1`

说明：脚本会在 ISO 根复制 `uya-kernel`、`limine-cd.bin`、`limine.cfg` 并打包为 `dist\uya.iso`，随后用 QEMU 以 `-serial stdio` 启动。

## 快速开始（Linux / WSL）
- 安装：`sudo apt install -y xorriso qemu-system-x86`
- 构建：`zig build`
- 打包：
  ```
  mkdir -p dist/iso_root
  cp zig-out/bin/uya-kernel dist/iso_root/uya-kernel
  cp third_party/limine/limine-cd.bin dist/iso_root/limine-cd.bin
  cp limine/limine.cfg dist/iso_root/limine.cfg
  xorriso -as mkisofs -b limine-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table \
    -J -R -input-charset utf-8 -output-charset utf-8 \
    -o dist/uya.iso dist/iso_root
  ```
- 运行：`qemu-system-x86_64 -m 512M -serial stdio -no-reboot -boot d -cdrom dist/uya.iso`

## 内核启动流程
- 入口：`src/kernel/main.zig:28` `_start` 完成串口、SMP、APIC、ACPI、内存映射、VFS、事件队列、调度与人格桥接的初始化，并进入主循环
- 构建入口：`build.zig:113` 安装内核可执行 `uya-kernel` 并设置链接脚本与符号入口
- 引导配置：`limine/limine.cfg:1-5` 使用 BIOS El Torito 启动 `uya-kernel`

## 关键特性
- 能力化与 Epoch 回收
  - 能力序列化/校验：`src/kernel/cap/cap_api.zig:21-28,46-47`
  - Epoch：`src/kernel/cap/epoch.zig:10-36`，与索引发布-复用结合，保障并发安全
- VFS（UyaFS）
  - 文件/目录索引的双缓冲发布：`fs/vfs.zig:58-142`
  - 能力化打开与子树撤销：`fs/vfs.zig:279-309,329-339`
- 事件与队列
  - SPSC/共享内存队列/每核队列/MPMC 全局队列：`src/kernel/event/events.zig:9-16,20-23,30-60,106-115,123-125`
  - MPMC 细节与 Epoch 回收：`src/kernel/util/mpmc.zig:34-52,74-101,102-121`
- 内存管理
  - 映射/保护/解除与缺页处理（radix + Epoch）：`mm/core.zig:48-57,59-74,76-89,91-107`
- 跨人格最小桥接
  - 调度器：`src/kernel/abi/persona.zig:6-12`
  - Win/Linux/BSD 子系统调用：`src/kernel/win/syscall.zig:4-16`、`src/kernel/abi/linux.zig:49-56`、`src/kernel/abi/bsd.zig:49-56`
- PE 装载与 IAT 解析：`src/kernel/win/pe.zig:58-85,233-248,263-314`

## 驱动中心与安全（新增）
- 自动移植与生成：`src/kernel/net/uyalink.zig:606-623` 路由到驱动中心生成移植稿（多个AI插件参与）。
- 安装/校验/回滚：
  - 安装分支：`src/kernel/net/uyalink.zig:624`（`Family.drv + Op.install`），驱动中心安装：`src/kernel/driver/center.zig:15-24`
  - 校验分支：`src/kernel/net/uyalink.zig:647`（`Family.drv + Op.verify`），驱动中心校验：`src/kernel/driver/center.zig:25-32`
  - 回滚分支：`src/kernel/net/uyalink.zig:668-682`（`Family.drv + Op.rollback`），驱动中心回滚：`src/kernel/driver/center.zig:33-38`
- 安全策略检查：
  - 安装策略：`/reg/security/drv_allow_install` 为 `false` 时拒绝，见 `src/kernel/net/uyalink.zig:636-644`
  - 回滚策略：`/reg/security/drv_allow_rollback` 为 `false` 时拒绝，见 `src/kernel/net/uyalink.zig:659-667`
- 审计记录：驱动中心在安装/校验/回滚时写入 `/audit/driver/<dev>/`，见 `src/kernel/driver/center.zig:18-33`

## GC 分代度量（新增）
- 对象头加入代龄 `gen`：`src/kernel/gc/api.zig:5`
- 周期收尾 `end_cycle()`：将存活对象升代并清标记，`src/kernel/gc/api.zig:99`
- 调度集成：每轮步进后调用收尾，`src/kernel/gc/sched.zig:4`
- 运行时参数与观测：`set_nursery_size/get_nursery_size/get_gen_avg`，`src/kernel/gc/api.zig:116-118`
- bench 输出：`GEN_AVG/NURSERY`，`src/kernel/tests/bench.zig:120-122`

## IPC 与套接字（新增）
- 双向端点与消息头
  - 创建端点：`src/kernel/event/events.zig:182-194`
  - 请求/响应（消息头 `id/flags/len/err/deadline_ms`）：
    - 发送请求：`src/kernel/event/events.zig:306-316`
    - 接收请求：`src/kernel/event/events.zig:318-357`
    - 发送响应：`src/kernel/event/events.zig:359-369`
    - 接收响应：`src/kernel/event/events.zig:371-410`
  - 批量收发：`src/kernel/event/events.zig:246-256,258-268`
  - 设置当前时间（用于 deadline）：`src/kernel/event/events.zig:154-155`
- 本地套接字封装
  - 成对创建：`src/kernel/net/socket.zig:6-11`
  - 监听/接受/连接/注销：`src/kernel/net/socket.zig:46-58,72-81,83-92,94-103`
  - 发送/接收：`src/kernel/net/socket.zig:13-19,21-33`
  - 批量与消息头：`src/kernel/net/socket.zig:118-124,126-132`
  - 扩展发送与重试：`src/kernel/net/socket.zig:134-145,147-151,153-159`

## 优先级与超时（新增）
- 三级优先队列：高/中/低，`flags & 3` 选择优先级；接收按高→中→低消费
- 超时回退：高/中队列的过期消息自动回退至低队列，低队列最佳努力交付
- 配额与令牌（流控）：
  - 为端点设置配额：`src/kernel/net/socket.zig:105-114`（路由名 → 端点），调用 `events.set_ep_quota`
  - 回压查询：`events.get_ep_backpressure`（同文件，端点层）

## 每核绑定（新增）
- 核心收发 API：
  - 发送到指定核心：`src/kernel/event/events.zig:159-167`
  - 从指定核心接收：`src/kernel/event/events.zig:169-180`
- 套接字核心绑定：`src/kernel/net/socket.zig:116`，绑定后 `send/recv` 走每核队列，减少跨核迁移
- 具名监听绑定核心：`src/kernel/net/socket.zig:60-70`，`accept/connect` 返回时保留核心信息

## 注册表（新增）
- 目标与结构
  - 内容寻址存储（CAS）：对象按 `algo/hash.blob` 存储，避免重复写入，见 `apps/registry/cas.zig:15-37`
  - 工作树（Worktree）：`registry/worktrees/<prefix>/<version>` 版本化布局，支持硬链接优先与回退复制，见 `apps/registry/worktree_win.zig:23-53`
  - 当前版本指示：`registry/worktrees/<prefix>/current` 文件记录当前版本，见 `apps/registry/worktree_win.zig:55-62`
- CLI 用法（Windows）
  - 存入文本：`zig-out\bin\uya-registry.exe put registry sky`（打印 SHA-256 十六进制）`apps/registry/cli.zig:11-16`
  - 存入文件：`zig-out\bin\uya-registry.exe put-file registry path\to\file` `apps/registry/cli.zig:17-24`
  - 链接到工作树：`zig-out\bin\uya-registry.exe link registry sha256 <hash_hex> org/uya/uyade accent v1` `apps/registry/cli.zig:25-35`
  - 切换当前版本：`zig-out\bin\uya-registry.exe switch registry org/uya/uyade v1` `apps/registry/cli.zig:35-41`
- 与 UyaDE 的联动
  - UyaDE 会从注册表工作树读取 `ui.dsl` 与主题数据并热重载布局，见 `apps/uyade/main.zig:145-218`

## 桌面环境（UyaDE）
- 入口：`apps/uyade/main.zig:30`
- 特性：任务栏、开始按钮、托盘、时钟；支持从“注册表工作树”与 `ui.dsl` 动态热重载主题与布局
- 启动：`zig build` 后运行 `zig-out\bin\uyade.exe`
- `ui.dsl` 示例：
  ```
  [theme]
  accent = "pink"

  [taskbar]
  orientation = "bottom"

  [clock]
  show_seconds = true

  [layout]
  children = ["taskbar", "start", "tray", "clock"]
  ```

### 标题栏特色（新增）
- Uya 默认同时提供左右六个按键：
  - 左侧（苹果风格）：`close min max`，默认值见 `apps/uyade/components/titlebar_layout.zig:9-10`
  - 右侧（微软风格）：`max min close`，默认值见同文件
- 可通过 UI DSL 配置：
  - `titlebar { layout = "apple" }`
  - `titlebar { controls.left = ["close","min","max"] }`
  - `titlebar { controls.right = ["max","min","close"] }`
  - 演示脚本示例：`scripts/setup_uyade_demo.ps1:10-11`

## 基准与度量（新增）
- 驱动闭环演示与审计计数输出：`src/kernel/tests/bench.zig:128-139`
- 合成器度量（行数/字节）与脏区/遮挡裁剪演示：`src/kernel/tests/bench.zig:55-79`
- VFS 热路径读压测与分页：`src/kernel/tests/bench.zig:12-25`，配合 `src/fs/vfs.zig`

## 与 Zorin OS 18 对比（实用性）
- 应用生态与驱动覆盖：Zorin 基于 Ubuntu，生态成熟；Uya 侧重内核/IPC/驱动移植框架与研究，生态待扩充。
- 桌面体验：Zorin 完整桌面栈与主题；UyaDE 可配置与“标题栏左右六键”特色，功能以原型为主。
- 性能与系统路径：Uya 具备轻量 IPC、并发 GC 与策略节拍、合成器脏区优化，适合定制化与高性能场景；Zorin 侧重稳定与广泛兼容。
- 安全与维护：Zorin 提供成熟的更新与安全机制；Uya 已接入安装/回滚策略与审计，版本工作树与回滚已可用，差分更新与图形/驱动覆盖在推进中。

## 注册表工具（Windows）
- 放置 CAS 对象并切换工作树：
  - 存储文本：`zig-out\bin\uya-registry.exe put registry sky`
  - 链接对象到工作树：`zig-out\bin\uya-registry.exe link registry sha256 <hash> org/uya/uyade accent v1`
  - 切换版本：`zig-out\bin\uya-registry.exe switch registry org/uya/uyade v1`
- CLI 入口：`apps/registry/cli.zig:5-42`
- Windows 硬链接优先：`apps/registry/worktree_win.zig:23-53`

## 常见问题
- 无法安装 `xorriso`：
  - 使用 `genisoimage/mkisofs`（脚本已自动回退）
  - 使用 `WSL` 安装并由脚本自动调用：`wsl --install` 后 `sudo apt install -y xorriso`
- 仅 UEFI 启动：默认 ISO 为 BIOS El Torito。需要 UEFI 双模式时，请额外加入 UEFI 引导镜像并调整打包参数（可在后续版本提供脚本）

## 贡献
- 提交 PR 前请确保：
  - 保持代码风格与现有模块一致
  - 遵循安全最佳实践（不泄漏秘钥/敏感信息）
  - 覆盖基础用例（事件队列/能力校验/VFS 读写）

## 许可
- 本项目采用木兰宽松许可证，第2版（Mulan PSL v2）。
- 你可以在满足许可证条款的前提下复制、使用、修改与分发本软件。
- 许可证全文与指引：`http://license.coscl.org.cn/MulanPSL2`

## 致谢
- Limine 引导与文档
- Zig 语言与生态
- 分布式持久化（初步）
  - 注册表写入生成复制日志：`/db/replica/log/<seq>`，顺序记录 `reg_set` 操作（TLV编码，含`key/value`与`db_kind`）
  - 序列号存储：`/db/replica/seq`（LE编码），用于下次递增，见 `src/kernel/net/uyalink.zig:435-461`
  - 审计镜像：驱动审计条目镜像到 `/db/driver_audit/<dev>/`，见 `src/kernel/driver/center.zig:18-33`
  - 后续将以可插拔后端适配分布式数据库，实现事务与流订阅，并保持本地回退路径

### DB 接口（新增）
- `Family.db + Op.list`：分页列出 `/db/replica/log` 的条目名（支持 `offset/limit`），见 `src/kernel/net/uyalink.zig:...`
- `Family.db + Op.get`：按 `db_seq` 读取日志条目内容（TLV编码数据），用于外部重放与校验，见 `src/kernel/net/uyalink.zig:...`
