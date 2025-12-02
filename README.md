# Uya 项目

## 项目概述
Uya 是一个基于 Zig 语言开发的操作系统项目，专注于提供高性能、可移植的系统架构。本项目探索现代操作系统设计理念，包括事件驱动模型、灵活的文件系统抽象、驱动管理以及用户空间应用生态。

### 许可证
本项目采用木兰宽松许可证 2.0 (MulanPSL-2.0)。

### 支持平台
- Windows（开发环境与部分功能）
- UEFI/BIOS 启动（ISO 构建支持）

## 目录结构
- `kernel/` - 内核核心目录
  - `src/` - 内核源代码
  - `fs/` - 文件系统实现
  - `mm/` - 内存管理
- `src/` - 源代码目录
  - `apps/` - 应用程序
  - `tools/` - 工具程序
  - `config/` - 配置文件
  - `common/` - 共享代码
- `apps/` - 用户空间应用
- `third_party/` - 第三方库管理
  - `bootloaders/` - 引导加载器
    - `limine/` - Limine引导加载器
    - `limine_codeberg/` - Limine源代码
  - `libraries/` - 第三方库
  - `tools/` - 第三方工具
- `build.zig` - Zig构建文件
- `iso/` - ISO相关文件

## 快速开始

### Windows 环境
```powershell
# 克隆仓库
git clone https://github.com/yourusername/uya.git
cd uya

# 安装依赖
# 确保已安装 Zig 编译器和构建工具链

# 构建项目
zig build

# 运行 ISO 构建（自动调用 iso_builder）
zig build iso
```

### Linux 环境
```bash
# 克隆仓库
git clone https://github.com/yourusername/uya.git
cd uya

# 安装依赖
sudo apt-get install xorriso # 或 genisoimage/mkisofs

# 构建项目
zig build

# 运行 ISO 构建
zig build iso
```

## ISO 构建器（新增）

### 功能概述
Uya 项目包含一个强大的 ISO 构建器，位于 `src/build/iso_builder.zig`，用于自动创建可启动的 ISO 镜像。

### 支持的 ISO 工具
ISO 构建器会自动检测并使用系统中可用的 ISO 工具，按以下优先级：
1. `xorriso` - 首选工具，功能最完整
2. `genisoimage` - 备选工具
3. `mkisofs` - 备选工具

### 构建过程
1. 自动创建 `dist/iso_root` 目录结构
2. 复制必要文件（内核、Limine 引导文件、字体等）
3. 生成可启动的 ISO 镜像

### 自定义 ISO 构建
```bash
# 仅构建 ISO（不重建内核）
zig build iso

# 完整构建（包括内核和 ISO）
zig build
```

### 常见问题
- **工具不可用**：如果系统中没有安装上述工具，ISO 构建会失败。请根据您的操作系统安装相应工具。
- **UEFI 支持**：当前 ISO 默认支持 BIOS 启动，UEFI 支持需要额外配置。

## 内核启动流程
1. `_start` 入口点初始化基本系统服务
2. 初始化内存管理、中断处理和调度器
3. 挂载虚拟文件系统（VFS）
4. 初始化驱动中心和事件系统
5. 启动用户空间应用

## 关键特性

### 能力化与特权管理
- 能力模型：`src/kernel/mm/capability.zig`
- 特权检查：针对所有敏感操作（如 `mm_alloc`，`src/mm/core.zig:20-30`）
- 权限传递：在对象创建/引用时自动传递权限向量，见 `src/mm/core.zig:126-135`

### VFS（虚拟文件系统）
- 统一命名空间：`vfs://` 前缀，支持分层挂载
- 挂载点管理：`src/fs/vfs.zig:35-42`（注册）、`src/fs/vfs.zig:44-52`（查找）
- 权限检查：挂载时验证权限，`src/fs/vfs.zig:48`

### 事件队列与消息传递
- 核心 API：`send`/`recv`/`poll`，见 `src/kernel/event/events.zig:117-123`
- 优先级队列：支持高/中/低三级优先级
- 每核绑定：减少跨核迁移，提高性能

### 驱动中心与安全（新增）
- 安全驱动架构：`src/kernel/driver/center.zig`，通过能力校验驱动操作，支持审计日志
- 审计计数：跟踪驱动 API 使用，见 `src/kernel/driver/center.zig:18-33`
- 驱动闭环演示与度量：`src/kernel/tests/bench.zig:128-139`

### 并发 GC 与策略节拍（新增）
- 并发垃圾收集器：`src/kernel/gc/collector.zig`
- 可配置回收策略：`src/kernel/gc/policy.zig`，支持基于时间/内存/手动触发
- 分代度量：跟踪对象年龄与引用，`src/kernel/gc/collector.zig:28-43`
- 插件化策略支持：`gc_policy_*.zig` 系列插件，见 `src/kernel/main.zig:182-193`

### IPC 与套接字（新增）
- 具名套接字：`src/kernel/net/socket.zig`，支持 `bind/listen/accept/connect`
- 消息路由：基于名称的端点解析，`src/kernel/net/socket.zig:182-196`
- 扩展发送与重试：`src/kernel/net/socket.zig:134-145,147-151,153-159`

### 优先级与超时（新增）
- 三级优先队列：高/中/低，`flags & 3` 选择优先级；接收按高→中→低消费
- 超时回退：高/中队列的过期消息自动回退至低队列，低队列最佳努力交付
- 配额与令牌（流控）：
  - 为端点设置配额：`src/kernel/net/socket.zig:105-114`（路由名 → 端点），调用 `events.set_ep_quota`
  - 回压查询：`events.get_ep_backpressure`（同文件，端点层）

### 每核绑定（新增）
- 核心收发 API：
  - 发送到指定核心：`src/kernel/event/events.zig:159-167`
  - 从指定核心接收：`src/kernel/event/events.zig:169-180`
- 套接字核心绑定：`src/kernel/net/socket.zig:116`，绑定后 `send/recv` 走每核队列，减少跨核迁移
- 具名监听绑定核心：`src/kernel/net/socket.zig:60-70`，`accept/connect` 返回时保留核心信息

### 注册表（新增）
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

# 桌面环境（UyaDE）
- 入口：`apps/uyade/main.zig:30`
- 特性：任务栏、开始按钮、托盘、时钟；支持从"注册表工作树"与 `ui.dsl` 动态热重载主题与布局
- 启动：`zig build` 后运行 `zig-out\bin\uyade.exe`
- 设计风格：
  - 遵循 **Material 3** 设计规范
  - 主色系：**莫兰迪色系**（高级灰调、低饱和度、柔和雾面质感）用于界面主要区域
  - 点缀色系：**马卡龙色系**（高明度、柔和糖果色）用于图标、按钮等小面积装饰
  - 整体呈现温柔优雅的现代感
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

### 标题栏特色
- Uya 默认同时提供左右六个按键：
  - 左侧（苹果风格）：`close min max`，默认值见 `apps/uyade/components/titlebar_layout.zig:9-10`
  - 右侧（微软风格）：`max min close`，默认值见同文件
- 集成搜索栏：
  - 位于标题栏中央或可配置位置
  - 支持全局应用搜索、文件快速定位
  - 实时搜索建议与智能补全
  - 采用马卡龙色系点缀，与整体设计风格协调
  - 快捷键支持快速唤起（如 Ctrl+Space）
- 可通过 UI DSL 配置：
  - `titlebar { layout = "apple" }`
  - `titlebar { controls.left = ["close","min","max"] }`
  - `titlebar { controls.right = ["max","min","close"] }`
  - `titlebar { search.enabled = true }`
  - `titlebar { search.position = "center" }`
  - 演示脚本示例：`scripts/setup_uyade_demo.ps1:10-11`

## WinBoat-Zig（新增）
- 位置：`apps/winboat-zig/`
- 说明：将 WinBoat（Windows 应用容器化运行工具）使用 Zig 重写并深度集成到 Uya 系统
- 核心功能：
  - 容器管理：支持 QEMU/KVM、Docker、Podman 等运行时
  - Guest Server：系统监控（CPU/内存/磁盘）、健康检查、RDP 连接状态
  - 应用管理：Windows 应用列表同步、自定义应用支持、使用统计
  - RDP 集成：RemoteApp 协议、多显示器支持、窗口无缝集成
  - QMP 通信：QEMU Machine Protocol 虚拟机控制
- 系统集成：
  - 与 UyaDE 深度集成，采用莫兰迪主色系和马卡龙点缀色
  - 窗口管理集成 UyaDE 标题栏系统
  - 文件系统共享与剪贴板同步
  - 使用 Uya 的 IPC/Socket 机制和注册表配置管理
- 构建：`cd apps/winboat-zig && zig build`
- 许可证：木兰宽松许可证 2.0 (MulanPSL-2.0)

## 基准与度量
- 驱动闭环演示与审计计数输出：`src/kernel/tests/bench.zig:128-139`
- 合成器度量（行数/字节）与脏区/遮挡裁剪演示：`src/kernel/tests/bench.zig:55-79`
- VFS 热路径读压测与分页：`src/kernel/tests/bench.zig:12-25`，配合 `src/fs/vfs.zig`

## 与 Zorin OS 18 对比（实用性）
- 应用生态与驱动覆盖：Zorin 基于 Ubuntu，生态成熟；Uya 侧重内核/IPC/驱动移植框架与研究，生态待扩充。
- 桌面体验：Zorin 完整桌面栈与主题；UyaDE 可配置与"标题栏左右六键"特色，功能以原型为主。
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