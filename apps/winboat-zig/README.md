# WinBoat-Zig

WinBoat 的 Zig 原生实现，集成到 Uya 操作系统中。

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

## 许可证

木兰宽松许可证 2.0 (MulanPSL-2.0)
