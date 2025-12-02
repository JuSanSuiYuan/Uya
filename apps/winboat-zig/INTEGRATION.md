# WinBoat 集成到 Uya 操作系统

## 集成概述

本文档描述如何将 WinBoat（用 Zig 重写）集成到 Uya 操作系统中。

## 项目结构

```
Uya/
└── apps/
    └── winboat-zig/           # WinBoat-Zig 实现
        ├── src/
        │   ├── main.zig       # 主入口
        │   ├── config/        # 配置管理
        │   │   ├── types.zig  # 类型定义
        │   │   └── store.zig  # 配置存储
        │   ├── container/     # 容器管理
        │   │   └── manager.zig
        │   ├── guest/         # Guest Server
        │   │   └── server.zig
        │   └── app/           # 应用管理
        │       └── manager.zig
        ├── build.zig          # 构建配置
        └── README.md          # 项目说明
```

## 已完成功能

### 1. 核心模块架构 ✅
- 配置类型定义（`config/types.zig`）
- 配置存储系统（`config/store.zig`）
- 主入口与核心逻辑（`main.zig`）

### 2. 容器管理模块 ✅
- 容器管理器（`container/manager.zig`）
- 支持 QEMU/KVM、Docker、Podman 运行时
- 容器生命周期管理（启动、停止、暂停、恢复）

### 3. Guest Server 模块 ✅
- HTTP 服务器框架（`guest/server.zig`）
- 系统指标监控（CPU、内存、磁盘）
- 健康状态检查
- RDP 连接状态监控

### 4. 应用管理模块 ✅
- 应用管理器（`app/manager.zig`）
- 应用列表同步
- 自定义应用添加/删除
- 使用统计跟踪

### 5. 配置管理 ✅
- 配置加载与保存
- 默认配置生成
- 虚拟机规格配置
- RDP 参数配置

## 待完成功能

### 1. RDP 集成 ⏳
需要实现：
- RDP 客户端包装（`rdp/client.zig`）
- FreeRDP 调用接口
- RemoteApp 协议支持
- 多显示器配置

### 2. QMP 通信 ⏳
需要实现：
- QMP 客户端（`qmp/client.zig`）
- QEMU Machine Protocol 命令封装
- 虚拟机控制接口

### 3. 系统监控增强 ⏳
需要实现：
- 实际的 CPU 指标收集
- 实际的内存指标收集
- 实际的磁盘指标收集
- 与 Uya 内核的系统调用集成

### 4. HTTP 服务器实现 ⏳
需要实现：
- 完整的 HTTP 服务器
- API 端点处理
- 使用 Uya 的 IPC/Socket 机制

### 5. UyaDE 界面集成 ⏳
需要实现：
- WinBoat 控制面板
- 应用启动器集成
- 系统监控仪表板
- 与 UyaDE 的 DSL 配置集成

## 构建与运行

### 构建 WinBoat-Zig

```powershell
cd d:\PROJECT\Uya\apps\winboat-zig
zig build
```

### 运行 WinBoat-Zig

```powershell
zig build run
```

### 运行测试

```powershell
zig build test
```

## 与 Uya 系统集成

### 1. 虚拟化集成
- 使用 Uya 的能力化（Capabilities）系统
- 通过 Uya 的系统调用访问 KVM
- 内存管理与 Uya MM 模块集成

### 2. IPC 集成
- 使用 Uya 的 IPC 双向端点
- 消息队列与事件系统
- 套接字封装用于 Guest 通信

### 3. 文件系统集成
- 使用 UyaFS 存储虚拟机镜像
- 配置文件存储在注册表工作树
- 应用缓存使用 CAS（内容寻址存储）

### 4. 桌面环境集成
- WinBoat 窗口通过 UyaDE 显示
- 使用 UyaDE 的标题栏布局系统
- 应用图标集成到任务栏和托盘

## 技术栈对比

| 功能模块 | WinBoat 原版 | WinBoat-Zig | 说明 |
|---------|-------------|-------------|------|
| 前端框架 | Electron + Vue | UyaDE (Zig) | 原生桌面环境 |
| 容器运行时 | Docker/Podman | QEMU/KVM | 更轻量的虚拟化 |
| Guest Server | Go HTTP | Zig + Uya IPC | 原生 IPC 通信 |
| 应用管理 | TypeScript | Zig | 类型安全 |
| 配置存储 | electron-store | Uya Registry | 统一配置管理 |
| RDP 客户端 | FreeRDP | FreeRDP/原生 | 可选原生实现 |

## 设计优势

### 1. 性能优化
- Zig 编译为原生代码，无 JS 运行时开销
- 直接内存管理，减少 GC 压力
- 与操作系统内核深度集成

### 2. 资源占用
- 无 Electron/Chromium 依赖
- 更小的内存占用
- 更快的启动速度

### 3. 系统集成
- 使用 Uya 的能力化安全模型
- 统一的配置管理（注册表）
- 原生桌面环境集成

### 4. 开发体验
- Zig 的编译时安全保证
- 清晰的错误处理
- 显式内存管理

## 下一步计划

1. **完成 RDP 集成**
   - 实现 FreeRDP 包装器
   - 支持 RemoteApp 协议
   - 多显示器配置

2. **实现 QMP 通信**
   - 完整的 QMP 客户端
   - 虚拟机控制命令
   - 热插拔支持

3. **增强系统监控**
   - 实际指标收集
   - 与 Uya 内核集成
   - 性能优化

4. **HTTP 服务器实现**
   - 基于 Uya IPC 的 HTTP 服务器
   - RESTful API 端点
   - WebSocket 支持（可选）

5. **UyaDE 界面开发**
   - 控制面板 UI
   - 应用启动器
   - 系统监控仪表板

6. **测试与优化**
   - 单元测试
   - 集成测试
   - 性能基准测试

## 许可证

木兰宽松许可证 2.0 (MulanPSL-2.0)

## 参考资料

- [Uya 操作系统](../../../README.md)
- [UyaDE 桌面环境](../uyade/README.md)
- [WinBoat 原项目](https://github.com/TibixDev/winboat)
- [Zig 语言文档](https://ziglang.org/documentation/master/)
