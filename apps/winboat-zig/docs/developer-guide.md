# WinBoat-Zig 开发者指南

本文档为 WinBoat-Zig 项目的开发者提供全面的技术参考，包括项目架构、代码组织、开发工作流程和扩展指南。

## 项目架构

### 整体架构

WinBoat-Zig 采用模块化架构设计，主要由以下核心组件组成：

1. **核心服务**：主控制流程和事件循环
2. **容器管理**：虚拟机生命周期管理
3. **Guest Server**：与 Windows 虚拟机通信的 HTTP 服务
4. **应用管理**：处理应用程序的启动、监控和终止
5. **配置系统**：管理各种配置选项
6. **监控模块**：收集系统和虚拟机性能指标

### 数据流

```
+------------------+       +-------------------+       +-------------------+
|                  |       |                   |       |                   |
|  用户界面/CLI   +------->+  核心服务组件     +------->+  容器管理模块     |
|                  |       |                   |       |                   |
+------------------+       +-------------------+       +-------------------+
                                      |                         |
                                      v                         v
+------------------+       +-------------------+       +-------------------+
|                  |       |                   |       |                   |
|  监控系统        |<------+  配置管理模块     |<------+  QEMU/KVM 接口    |
|                  |       |                   |       |                   |
+------------------+       +-------------------+       +-------------------+
                                      |
                                      v
                             +-------------------+
                             |                   |
                             |  Guest Server     |
                             |  (Windows端)      |
                             |                   |
                             +-------------------+
```

## 代码结构

```
src/
├── main.zig                 # 程序主入口点
├── cli/                     # 命令行接口
│   ├── parser.zig           # 命令行解析器
│   └── commands.zig         # 命令实现
├── container/               # 容器管理
│   ├── manager.zig          # 容器管理器
│   ├── runtime.zig          # 运行时抽象
│   └── types.zig            # 类型定义
├── guest/                   # Guest Server
│   ├── server.zig           # HTTP服务器
│   ├── api.zig              # API处理
│   └── types.zig            # 类型定义
├── app/                     # 应用管理
│   ├── manager.zig          # 应用管理器
│   └── registry.zig         # 应用注册表
├── config/                  # 配置管理
│   ├── store.zig            # 配置存储
│   └── parser.zig           # 配置解析器
├── monitor/                 # 监控系统
│   ├── metrics.zig          # 指标收集
│   └── stats.zig            # 统计数据处理
├── utils/                   # 工具函数
│   ├── logger.zig           # 日志系统
│   └── errors.zig           # 错误处理
└── types/                   # 共享类型
    ├── common.zig           # 通用类型
    └── protocol.zig         # 协议定义
```

## 开发环境设置

### 安装依赖

1. **Zig 编译器**
   - 下载地址：https://ziglang.org/download/
   - 推荐版本：0.11.0 或更高

2. **开发依赖**
   - QEMU/KVM 开发库
   - libvirt 开发库（可选）
   - Git

3. **推荐开发工具**
   - VSCode + Zig 扩展
   - Zig Language Server (zls)

### 开发工作流程

#### 克隆代码库

```bash
git clone https://your-repo-url/winboat-zig.git
cd winboat-zig
```

#### 构建项目

```bash
# 开发构建（包含调试信息）
zig build

# 发布构建
zig build -Doptimize=ReleaseSafe

# 最小化大小构建
zig build -Doptimize=ReleaseSmall
```

#### 运行测试

```bash
# 运行所有测试
zig build test

# 运行特定测试
zig build test -- <test_name>
```

#### 代码风格检查

```bash
# 使用内置的 fmt 工具检查代码风格
zig fmt --check .

# 自动格式化代码
zig fmt .
```

## 开发指南

### 代码风格约定

1. **命名规范**
   - 类型名称：PascalCase
   - 函数名称：camelCase
   - 变量和参数：camelCase
   - 常量：SCREAMING_SNAKE_CASE
   - 文件和模块：snake_case

2. **代码格式化**
   - 使用 `zig fmt` 自动格式化代码
   - 缩进使用空格（4个空格）
   - 最大行长度：100 字符

3. **注释规范**
   - 公共 API 使用文档注释（`///`）
   - 模块级注释使用块注释（`//!`）
   - 复杂逻辑添加解释性注释

### 错误处理模式

WinBoat-Zig 使用 Zig 的错误联合类型进行错误处理：

```zig
// 定义错误集
const Error = error{
    FileNotFound,
    PermissionDenied,
    InvalidFormat,
};

// 返回可能出错的函数
pub fn openFile(path: []const u8) Error!File {
    // 实现...
}

// 调用示例
pub fn processData() !void {
    const file = try openFile("config.yaml");
    defer file.close();
    // 处理文件...
}
```

### 内存管理

1. **使用分配器**
   - 所有动态内存分配都应通过显式分配器进行
   - 考虑使用 `GeneralPurposeAllocator` 进行调试

2. **内存安全**
   - 使用 `defer` 确保资源正确释放
   - 避免使用 `@fieldParentPtr` 除非绝对必要
   - 优先使用栈分配而不是堆分配

3. **推荐模式**

```zig
pub fn processLargeData(allocator: Allocator, input: []const u8) ![]u8 {
    // 分配内存
    const result = try allocator.alloc(u8, input.len * 2);
    // 确保在出错时释放
    errdefer allocator.free(result);
    
    // 处理数据...
    
    return result;
}
```

## 扩展指南

### 添加新命令

1. 在 `src/cli/commands.zig` 中添加新命令实现
2. 在 `src/cli/parser.zig` 中注册新命令
3. 实现相应的业务逻辑

### 添加新的虚拟机运行时

1. 在 `src/container/runtime.zig` 中实现 `ContainerRuntime` 接口
2. 在容器管理器中注册新的运行时实现
3. 确保实现所有必要的生命周期方法

### 添加新的 API 端点

1. 在 `src/guest/api.zig` 中添加新的处理函数
2. 在 HTTP 服务器中注册新的路由
3. 实现必要的请求/响应处理

## 测试策略

### 单元测试

```zig
const std = @import("std");
const testing = std.testing;
const MyModule = @import("my_module.zig");

test "example test" {
    const result = MyModule.someFunction(42);
    try testing.expectEqual(@as(i32, 84), result);
}
```

### 集成测试

将集成测试放在 `tests/` 目录下，并使用专用的测试运行器。

## 调试技巧

1. **使用日志系统**
   - `std.debug.print` - 简单调试输出
   - 项目的日志系统 - 结构化日志记录

2. **内存调试**
   - 启用 `GeneralPurposeAllocator` 检测内存泄漏
   - 使用 `zig build test -freference-tracing` 跟踪内存引用

3. **QEMU 调试**
   - 添加 `-s` 参数启用 GDB 服务器
   - 使用 `winboat vm start --debug` 启动调试会话

## 贡献指南

1. **提交流程**
   - Fork 代码仓库
   - 创建功能分支 (`git checkout -b feature/amazing-feature`)
   - 提交更改 (`git commit -m 'Add some amazing feature'`)
   - 推送到分支 (`git push origin feature/amazing-feature`)
   - 开启 Pull Request

2. **代码审查标准**
   - 代码通过所有测试
   - 符合项目代码风格
   - 包含适当的文档和注释
   - 没有明显的内存泄漏或性能问题

3. **版本控制规范**
   - 使用语义化版本控制
   - 主要版本：API 不兼容变更
   - 次要版本：向后兼容的功能性新增
   - 补丁版本：向后兼容的问题修复

## 发布流程

1. 更新版本号
2. 运行所有测试确保质量
3. 构建发布版本
4. 创建发布标签
5. 生成发布说明

---

*本指南适用于 WinBoat-Zig 项目，最后更新时间：2025-12-02*