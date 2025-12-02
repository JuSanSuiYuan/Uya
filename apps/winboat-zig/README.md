# WinBoat-Zig

WinBoat 的 Zig 原生实现，集成到 Uya 操作系统中，提供 Windows 应用的无缝运行体验。

## 项目简介

WinBoat-Zig 是一个轻量级的虚拟化应用容器平台，专为 Uya 操作系统设计，允许用户在 Linux 环境中流畅运行 Windows 应用程序。该项目采用现代 C/S 架构，通过 QEMU/KVM 提供高性能的虚拟化支持，并实现了与 Uya 桌面环境的深度集成。

## 架构设计

### 模块结构

```
apps/winboat-zig/
├── src/
│   ├── main.zig              # 主入口
│   ├── container/            # 容器管理模块
│   │   ├── manager.zig       # 容器管理器
│   │   ├── runtime.zig       # 运行时抽象（Docker/Podman）
│   │   └── compose.zig       # Compose 配置解析
│   ├── guest/                # Guest Server 模块
│   │   ├── server.zig        # HTTP 服务器
│   │   ├── api.zig           # API 端点处理
│   │   └── auth.zig          # 认证管理
│   ├── app/                  # 应用管理模块
│   │   ├── manager.zig       # 应用管理器
│   │   └── cache.zig         # 应用缓存
│   ├── rdp/                  # RDP 集成模块
│   │   ├── client.zig        # RDP 客户端包装
│   │   └── config.zig        # RDP 配置
│   ├── qmp/                  # QEMU Machine Protocol
│   │   ├── client.zig        # QMP 客户端
│   │   └── commands.zig      # QMP 命令封装
│   ├── monitor/              # 系统监控模块
│   │   ├── metrics.zig       # 指标收集
│   │   └── stats.zig         # 统计信息
│   └── config/               # 配置管理
│       ├── store.zig         # 配置存储
│       └── types.zig         # 配置类型定义
└── build.zig                 # 构建配置
```

## 核心功能

### 1. 容器管理
- 支持 QEMU/KVM 虚拟化
- Windows 虚拟机生命周期管理
- 资源配额控制

### 2. Guest 通信
- 基于 IPC/Socket 的 Guest 通信协议
- 应用列表同步
- 系统指标监控

### 3. 应用启动
- RemoteApp 协议支持
- 应用窗口集成
- 多显示器支持

### 4. 系统集成
- 与 UyaDE 桌面环境深度集成
  - 主界面采用莫兰迪色系（高级灰调、低饱和度、柔和雾面质感）
  - 图标和按钮使用马卡龙色系（高明度、柔和糖果色）
  - 遵循 Material 3 设计规范
- 文件系统共享
- 剪贴板同步
- 窗口管理与 UyaDE 标题栏系统集成

## 安装与构建

### 前提条件

- Zig 编译器 0.11.0 或更高版本
- QEMU/KVM 虚拟化环境
- 至少 4GB RAM
- 至少 20GB 磁盘空间

### 构建步骤

```bash
# 克隆代码仓库
cd /path/to/Uya/apps

# 编译项目
zig build -Doptimize=ReleaseSafe

# 运行测试
zig build test
```

## 配置指南

### 配置文件

WinBoat-Zig 使用 YAML 格式的配置文件，默认位于 `~/.config/winboat/config.yaml`：

```yaml
# 虚拟机配置
vm:
  memory_mb: 4096      # 虚拟机内存大小（MB）
  cpus: 2              # CPU 核心数
  disk_gb: 20          # 磁盘大小（GB）
  display: "auto"       # 显示配置（auto/vga/headless）
  network: "bridge"     # 网络模式（nat/bridge/host）

# Guest Server 配置
guest_server:
  enabled: true         # 是否启用 Guest Server
  port: 8080            # HTTP 服务端口
  auth_enabled: false   # 是否启用认证

# 容器运行时配置
container:
  runtime: "qemu"       # 运行时类型（qemu/docker/podman）
  timeout: 30           # 操作超时时间（秒）
```

## 使用指南

### 启动 WinBoat

```bash
# 启动 WinBoat 服务
zig-out/bin/winboat start

# 查看状态
zig-out/bin/winboat status
```

### 管理虚拟机

```bash
# 列出所有虚拟机
zig-out/bin/winboat vm list

# 启动虚拟机
zig-out/bin/winboat vm start <vm_name>

# 停止虚拟机
zig-out/bin/winboat vm stop <vm_name>

# 暂停虚拟机
zig-out/bin/winboat vm pause <vm_name>

# 恢复虚拟机
zig-out/bin/winboat vm resume <vm_name>
```

### 管理应用

```bash
# 列出可用的 Windows 应用
zig-out/bin/winboat app list

# 启动应用
zig-out/bin/winboat app start "Windows Explorer"

# 停止应用
zig-out/bin/winboat app stop <app_id>
```

### 系统监控

```bash
# 查看系统指标
zig-out/bin/winboat metrics

# 导出日志
zig-out/bin/winboat log export
```

## 开发指南

### 代码结构

该项目遵循模块化设计，各个模块职责清晰：

- `container/`: 容器和虚拟机管理
- `guest/`: 与 Windows 来宾系统通信
- `app/`: 应用程序管理
- `config/`: 配置管理
- `monitor/`: 系统监控

### 贡献流程

1. Fork 代码仓库
2. 创建功能分支
3. 提交代码变更
4. 运行测试
5. 创建 Pull Request

## 故障排查

### 常见问题

#### 虚拟机启动失败
- 检查是否安装了 QEMU/KVM
- 验证用户是否在 kvm 组中
- 检查配置文件中的资源设置

#### 应用启动问题
- 确认 Guest Server 已启动并运行
- 检查 RDP 连接是否正常
- 验证 Windows 虚拟机中的应用是否存在

## 许可证

项目采用 **木兰宽松许可证 2.0 (MulanPSL-2.0)** 开源。

```
MulanPSL-2.0

https://license.coscl.org.cn/MulanPSL2
```
