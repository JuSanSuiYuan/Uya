# WinBoat-Zig 配置文档

本文档详细说明 WinBoat-Zig 的配置系统，包括配置文件格式、配置项说明以及如何修改配置。

## 1. 配置文件

### 1.1 配置文件位置

WinBoat-Zig 使用以下顺序查找配置文件：

1. 命令行参数指定的配置文件（`--config` 或 `-c` 选项）
2. 当前工作目录下的 `config.yaml`
3. 用户目录下的 `.winboat/config.yaml`
4. 系统配置目录下的 `winboat/config.yaml`

### 1.2 配置文件格式

WinBoat-Zig 使用 YAML 格式的配置文件，具有层次结构。以下是一个完整的配置文件示例：

```yaml
# 日志配置
log:
  level: info          # 日志级别: debug, info, warn, error
  file: logs/winboat.log  # 日志文件路径，不设置则输出到控制台
  max_size: 10         # 单个日志文件最大大小(MB)
  max_files: 5         # 保留的最大日志文件数

# 容器运行时配置
container:
  runtime: "winbox"    # 运行时类型: winbox, wsl
  memory_limit: 4096   # 内存限制(MB)
  cpu_limit: 2         # CPU 核心数限制
  disk_path: "/var/winboat/disks"  # 虚拟机磁盘存储路径
  snapshot_path: "/var/winboat/snapshots"  # 快照存储路径

# Guest Server 配置
guest_server:
  enabled: true        # 是否启用 Guest Server
  port: 8080           # HTTP 服务端口
  host: "0.0.0.0"      # 监听地址
  timeout: 30          # 连接超时时间(秒)
  max_connections: 100 # 最大连接数

# Windows 虚拟机配置
windows:
  username: "Administrator"  # 管理员用户名
  password: ""          # 管理员密码，建议通过环境变量设置
  rdp_port: 3389       # RDP 端口
  winrm_port: 5985     # WinRM 端口
  shared_folder: ""    # 共享文件夹路径
  network_mode: "bridge"  # 网络模式: bridge, nat

# 应用管理配置
apps:
  startup_delay: 30    # 启动延迟(秒)
  max_startup_time: 60 # 应用最大启动时间(秒)
  default_timeout: 300 # 默认操作超时时间(秒)

# 安全配置
security:
  api_key: ""          # API 密钥，建议通过环境变量设置
  disable_auth: false  # 是否禁用认证（仅开发环境）
  allowed_ips: ["127.0.0.1", "10.0.0.0/8"]  # 允许访问的 IP 地址

# 系统集成配置
integration:
  uya_de: true         # 是否集成 UyaDE 桌面环境
  icon_theme: "default" # 图标主题
  theme_color: "#0078d7" # 主题色
```

## 2. 配置项说明

### 2.1 日志配置 (log)

| 配置项 | 类型 | 默认值 | 说明 | 必选 |
|--------|------|--------|------|------|
| level | string | info | 日志级别，可选值：debug, info, warn, error | 否 |
| file | string | "" | 日志文件路径，为空时输出到控制台 | 否 |
| max_size | integer | 10 | 单个日志文件最大大小（MB） | 否 |
| max_files | integer | 5 | 保留的最大日志文件数量 | 否 |

### 2.2 容器运行时配置 (container)

| 配置项 | 类型 | 默认值 | 说明 | 必选 |
|--------|------|--------|------|------|
| runtime | string | winbox | 容器运行时，可选值：winbox, wsl | 否 |
| memory_limit | integer | 4096 | 内存限制（MB） | 否 |
| cpu_limit | integer | 2 | CPU 核心数限制 | 否 |
| disk_path | string | "/var/winboat/disks" | 虚拟机磁盘存储路径 | 否 |
| snapshot_path | string | "/var/winboat/snapshots" | 快照存储路径 | 否 |

### 2.3 Guest Server 配置 (guest_server)

| 配置项 | 类型 | 默认值 | 说明 | 必选 |
|--------|------|--------|------|------|
| enabled | boolean | true | 是否启用 Guest Server | 否 |
| port | integer | 8080 | HTTP 服务端口 | 否 |
| host | string | "0.0.0.0" | 监听地址 | 否 |
| timeout | integer | 30 | 连接超时时间（秒） | 否 |
| max_connections | integer | 100 | 最大连接数 | 否 |

### 2.4 Windows 虚拟机配置 (windows)

| 配置项 | 类型 | 默认值 | 说明 | 必选 |
|--------|------|--------|------|------|
| username | string | "Administrator" | 管理员用户名 | 否 |
| password | string | "" | 管理员密码，建议通过环境变量设置 | 否 |
| rdp_port | integer | 3389 | RDP 端口 | 否 |
| winrm_port | integer | 5985 | WinRM 端口 | 否 |
| shared_folder | string | "" | 共享文件夹路径 | 否 |
| network_mode | string | "bridge" | 网络模式，可选值：bridge, nat | 否 |

### 2.5 应用管理配置 (apps)

| 配置项 | 类型 | 默认值 | 说明 | 必选 |
|--------|------|--------|------|------|
| startup_delay | integer | 30 | 应用启动延迟（秒） | 否 |
| max_startup_time | integer | 60 | 应用最大启动时间（秒） | 否 |
| default_timeout | integer | 300 | 默认操作超时时间（秒） | 否 |

### 2.6 安全配置 (security)

| 配置项 | 类型 | 默认值 | 说明 | 必选 |
|--------|------|--------|------|------|
| api_key | string | "" | API 密钥，建议通过环境变量设置 | 否 |
| disable_auth | boolean | false | 是否禁用认证（仅开发环境） | 否 |
| allowed_ips | array | ["127.0.0.1", "10.0.0.0/8"] | 允许访问的 IP 地址或网段 | 否 |

### 2.7 系统集成配置 (integration)

| 配置项 | 类型 | 默认值 | 说明 | 必选 |
|--------|------|--------|------|------|
| uya_de | boolean | true | 是否集成 UyaDE 桌面环境 | 否 |
| icon_theme | string | "default" | 图标主题 | 否 |
| theme_color | string | "#0078d7" | 主题色 | 否 |

## 3. 命令行配置选项

除了配置文件外，WinBoat-Zig 还支持通过命令行参数覆盖配置项。命令行参数的优先级高于配置文件。

### 3.1 全局选项

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `--config`, `-c` | 指定配置文件路径 | 自动查找 |
| `--log-level`, `-l` | 设置日志级别 | 配置文件中的 log.level |
| `--help`, `-h` | 显示帮助信息 | - |
| `--version`, `-v` | 显示版本信息 | - |

### 3.2 vm 命令选项

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `--name`, `-n` | 虚拟机名称 | - |
| `--cpu` | CPU 核心数 | 配置文件中的 container.cpu_limit |
| `--memory` | 内存大小(MB) | 配置文件中的 container.memory_limit |
| `--disk-size` | 磁盘大小(GB) | 50 |
| `--snapshot` | 从快照创建 | - |

### 3.3 app 命令选项

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `--timeout`, `-t` | 操作超时时间(秒) | 配置文件中的 apps.default_timeout |
| `--env`, `-e` | 设置环境变量 | - |
| `--args` | 应用参数 | - |

## 4. 环境变量

WinBoat-Zig 支持使用环境变量设置敏感配置项，这样可以避免在配置文件中存储敏感信息。

### 4.1 支持的环境变量

| 环境变量 | 对应配置项 | 说明 |
|----------|------------|------|
| `WINBOAT_WINDOWS_PASSWORD` | windows.password | Windows 管理员密码 |
| `WINBOAT_API_KEY` | security.api_key | API 密钥 |
| `WINBOAT_LOG_LEVEL` | log.level | 日志级别 |
| `WINBOAT_LOG_FILE` | log.file | 日志文件路径 |
| `WINBOAT_PORT` | guest_server.port | Guest Server 端口 |
| `WINBOAT_HOST` | guest_server.host | Guest Server 监听地址 |

### 4.2 使用示例

```bash
# Linux/macOS
export WINBOAT_WINDOWS_PASSWORD="YourSecurePassword"
export WINBOAT_API_KEY="your-api-key-here"
winboat service start

# Windows PowerShell
$env:WINBOAT_WINDOWS_PASSWORD = "YourSecurePassword"
$env:WINBOAT_API_KEY = "your-api-key-here"
winboat service start

# Windows CMD
set WINBOAT_WINDOWS_PASSWORD=YourSecurePassword
set WINBOAT_API_KEY=your-api-key-here
winboat service start
```

## 5. 配置管理命令

WinBoat-Zig 提供了 `config` 命令用于管理配置。

### 5.1 查看所有配置

```bash
winboat config list
```

### 5.2 获取配置项

```bash
winboat config get container.runtime
# 输出: winbox
```

### 5.3 设置配置项

```bash
winboat config set container.memory_limit 8192
winboat config set log.level debug
```

### 5.4 重置配置

```bash
# 重置单个配置项到默认值
winboat config reset container.cpu_limit

# 重置所有配置到默认值
winboat config reset --all
```

### 5.5 保存配置

```bash
winboat config save
```

## 6. 高级配置

### 6.1 条件配置

WinBoat-Zig 支持根据环境变量或系统信息设置不同的配置。在配置文件中使用 `{{...}}` 语法：

```yaml
container:
  memory_limit: {{ env("WINBOAT_MEMORY", "4096") }}  # 使用环境变量或默认值
  cpu_limit: {{ env("WINBOAT_CPU", "2") }}

log:
  level: {{ env("NODE_ENV", "development") == "production" ? "info" : "debug" }}
```

### 6.2 包含其他配置文件

可以使用 `include` 关键字包含其他配置文件：

```yaml
# 包含基础配置
include: ./base_config.yaml

# 覆盖特定配置
log:
  level: debug
```

## 7. 配置验证

WinBoat-Zig 在启动时会验证配置文件的有效性。如果配置无效，会输出错误信息并退出。

可以使用以下命令验证配置文件：

```bash
winboat config validate
```

### 7.1 常见配置错误

1. **端口占用**：如果配置的端口已被其他进程占用，启动会失败。解决方法是修改端口配置或关闭占用端口的进程。

2. **路径不存在**：如果配置的路径（日志、磁盘等）不存在，WinBoat-Zig 会尝试创建目录，但如果没有权限会失败。

3. **配置项类型错误**：配置项的类型必须与预期一致。例如，端口必须是整数，路径必须是字符串。

4. **敏感信息泄露**：不要在版本控制系统中存储包含密码等敏感信息的配置文件。使用环境变量或单独的配置文件。

## 8. 默认配置文件模板

以下是一个完整的默认配置文件模板，可以保存为 `config.yaml` 并根据需要修改：

```yaml
# WinBoat-Zig 默认配置文件

log:
  level: info
  file: ""
  max_size: 10
  max_files: 5

container:
  runtime: "winbox"
  memory_limit: 4096
  cpu_limit: 2
  disk_path: "disks"
  snapshot_path: "snapshots"

guest_server:
  enabled: true
  port: 8080
  host: "127.0.0.1"
  timeout: 30
  max_connections: 100

windows:
  username: "Administrator"
  password: ""  # 请使用 WINBOAT_WINDOWS_PASSWORD 环境变量
  rdp_port: 3389
  winrm_port: 5985
  shared_folder: ""
  network_mode: "nat"

apps:
  startup_delay: 30
  max_startup_time: 60
  default_timeout: 300

security:
  api_key: ""  # 请使用 WINBOAT_API_KEY 环境变量
  disable_auth: false
  allowed_ips: ["127.0.0.1"]

integration:
  uya_de: true
  icon_theme: "default"
  theme_color: "#0078d7"
```

## 9. 配置迁移

当升级 WinBoat-Zig 时，如果配置格式发生变化，可以使用以下命令迁移旧配置：

```bash
winboat config migrate --from old_config.yaml --to new_config.yaml
```

---

*本文档最后更新时间：2025-12-02*

*版权所有 © 2025 WinBoat-Zig 项目 - 木兰宽松许可证 2.0 (MulanPSL-2.0)*