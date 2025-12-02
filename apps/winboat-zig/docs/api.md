# WinBoat-Zig API 文档

本文档提供了 WinBoat-Zig 的 API 规范，包括命令行接口、HTTP API 和内部库 API，帮助开发者了解如何与 WinBoat-Zig 进行交互和集成。

## 1. 命令行接口 (CLI)

### 1.1 基本语法

```bash
winboat [命令] [子命令] [选项] [参数]
```

### 1.2 核心命令

#### 1.2.1 vm 命令

**描述**：管理虚拟机

**子命令**：
- `create` - 创建新虚拟机
- `list` - 列出所有虚拟机
- `start` - 启动虚拟机
- `stop` - 停止虚拟机
- `pause` - 暂停虚拟机
- `resume` - 恢复虚拟机
- `status` - 查看虚拟机状态
- `delete` - 删除虚拟机

**使用示例**：
```bash
# 创建新虚拟机
winboat vm create --name windows11 --disk-size 50 --memory 8192 --cpus 4

# 启动虚拟机
winboat vm start windows11
```

#### 1.2.2 app 命令

**描述**：管理应用程序

**子命令**：
- `list` - 列出可用应用
- `start` - 启动应用
- `stop` - 停止应用
- `running` - 列出运行中的应用
- `info` - 查看应用详情

**使用示例**：
```bash
# 启动应用
winboat app start "Microsoft Word"

# 查看运行中的应用
winboat app running
```

#### 1.2.3 config 命令

**描述**：管理配置

**子命令**：
- `set` - 设置配置项
- `get` - 获取配置项
- `list` - 列出所有配置
- `reset` - 重置配置

**使用示例**：
```bash
# 设置配置项
winboat config set guest_server.port 8080

# 获取配置项
winboat config get container.runtime
```

#### 1.2.4 service 命令

**描述**：管理 WinBoat 服务

**子命令**：
- `start` - 启动服务
- `stop` - 停止服务
- `restart` - 重启服务
- `status` - 查看服务状态

**使用示例**：
```bash
# 启动服务
winboat service start

# 查看服务状态
winboat service status
```

## 2. HTTP API

### 2.1 API 基础

**Base URL**: `http://localhost:8080/api/v1`

**认证**：可选的 API 密钥认证

**请求格式**：JSON

**响应格式**：JSON

### 2.2 虚拟机管理 API

#### 2.2.1 获取虚拟机列表

**请求**：
```
GET /vms
```

**响应**：
```json
{
  "vms": [
    {
      "id": "vm-123",
      "name": "windows11",
      "status": "running",
      "cpu": 2,
      "memory": 4096,
      "diskSize": 50,
      "createdAt": "2025-12-02T10:00:00Z"
    }
  ],
  "total": 1
}
```

#### 2.2.2 启动虚拟机

**请求**：
```
POST /vms/{vmId}/start
```

**响应**：
```json
{
  "success": true,
  "message": "虚拟机启动成功",
  "vmId": "vm-123"
}
```

#### 2.2.3 停止虚拟机

**请求**：
```
POST /vms/{vmId}/stop
Content-Type: application/json

{
  "force": false
}
```

**响应**：
```json
{
  "success": true,
  "message": "虚拟机停止成功",
  "vmId": "vm-123"
}
```

### 2.3 应用程序 API

#### 2.3.1 获取应用列表

**请求**：
```
GET /apps?search=notepad
```

**响应**：
```json
{
  "apps": [
    {
      "id": "app-456",
      "name": "Notepad",
      "path": "C:\\Windows\\System32\\notepad.exe",
      "description": "Windows 记事本"
    }
  ],
  "total": 1
}
```

#### 2.3.2 启动应用

**请求**：
```
POST /apps/start
Content-Type: application/json

{
  "appId": "app-456",
  "args": ["C:\\path\\to\\file.txt"]
}
```

**响应**：
```json
{
  "success": true,
  "processId": "proc-789",
  "message": "应用启动成功"
}
```

#### 2.3.3 获取运行中的应用

**请求**：
```
GET /apps/running
```

**响应**：
```json
{
  "processes": [
    {
      "id": "proc-789",
      "appId": "app-456",
      "appName": "Notepad",
      "pid": 1234,
      "startedAt": "2025-12-02T10:15:00Z",
      "cpuUsage": 1.2,
      "memoryUsage": 5.4
    }
  ],
  "total": 1
}
```

### 2.4 系统监控 API

#### 2.4.1 获取系统指标

**请求**：
```
GET /metrics
```

**响应**：
```json
{
  "cpu": {
    "usage": 45.6,
    "frequency": 3200,
    "cores": 4
  },
  "ram": {
    "total": 8192,
    "used": 3200,
    "percentage": 39.1
  },
  "disk": {
    "total": 50,
    "used": 25,
    "percentage": 50.0
  },
  "timestamp": "2025-12-02T10:30:00Z"
}
```

## 3. 库 API (Zig)

### 3.1 容器管理 API

#### 3.1.1 ContainerManager

**描述**：容器管理器，负责虚拟机的生命周期管理

**主要方法**：

```zig
// 初始化容器管理器
pub fn init(allocator: Allocator) !ContainerManager

// 获取容器状态
pub fn getStatus(self: *ContainerManager, containerName: []const u8) !ContainerStatus

// 启动容器
pub fn start(self: *ContainerManager, containerName: []const u8) !void

// 停止容器
pub fn stop(self: *ContainerManager, containerName: []const u8, force: bool) !void

// 暂停容器
pub fn pause(self: *ContainerManager, containerName: []const u8) !void

// 恢复容器
pub fn resume(self: *ContainerManager, containerName: []const u8) !void

// 释放资源
pub fn deinit(self: *ContainerManager) void
```

**使用示例**：
```zig
const allocator = std.heap.page_allocator;
var manager = try container.ContainerManager.init(allocator);
defer manager.deinit();

try manager.start("windows11");
const status = try manager.getStatus("windows11");
```

### 3.2 Guest Server API

#### 3.2.1 GuestServer

**描述**：Guest Server HTTP 服务器，提供与 Windows 虚拟机通信的接口

**主要方法**：

```zig
// 初始化 Guest Server
pub fn init(allocator: Allocator, port: u16) !GuestServer

// 启动 HTTP 服务器
pub fn start(self: *GuestServer) !void

// 停止 HTTP 服务器
pub fn stop(self: *GuestServer) !void

// 获取健康状态
pub fn getHealth(self: *GuestServer) bool

// 获取系统指标
pub fn getMetrics(self: *GuestServer) !types.Metrics

// 释放资源
pub fn deinit(self: *GuestServer) void
```

**使用示例**：
```zig
var server = try guest.GuestServer.init(allocator, 8080);
defer server.deinit();

try server.start();
const metrics = try server.getMetrics();
```

### 3.3 配置管理 API

#### 3.3.1 ConfigStore

**描述**：配置存储，负责读写和管理配置

**主要方法**：

```zig
// 初始化配置存储
pub fn init(allocator: Allocator, configPath: []const u8) !ConfigStore

// 获取配置值
pub fn get(self: *ConfigStore, key: []const u8) ?[]const u8

// 设置配置值
pub fn set(self: *ConfigStore, key: []const u8, value: []const u8) !void

// 保存配置到文件
pub fn save(self: *ConfigStore) !void

// 释放资源
pub fn deinit(self: *ConfigStore) void
```

**使用示例**：
```zig
var config = try ConfigStore.init(allocator, "config.yaml");
defer config.deinit();

const port = config.get("guest_server.port") orelse "8080";
try config.set("container.runtime", "qemu");
try config.save();
```

## 4. 事件 API

### 4.1 事件类型

WinBoat-Zig 发出以下类型的事件：

- `vm.created` - 虚拟机创建完成
- `vm.started` - 虚拟机启动完成
- `vm.stopped` - 虚拟机停止完成
- `vm.paused` - 虚拟机暂停完成
- `vm.resumed` - 虚拟机恢复完成
- `app.started` - 应用启动完成
- `app.stopped` - 应用停止完成
- `error.occurred` - 发生错误
- `system.metrics` - 系统指标更新

### 4.2 事件订阅

**命令行**：
```bash
winboat events subscribe --event vm.started,app.started
```

**API**：
```
POST /events/subscribe
Content-Type: application/json

{
  "events": ["vm.started", "app.started"],
  "webhook": "http://localhost:3000/webhook"
}
```

## 5. 错误处理

### 5.1 错误码

WinBoat-Zig 使用以下错误码系统：

| 错误码 | 描述 | HTTP 状态码 |
|--------|------|-------------|
| 1001 | 虚拟机不存在 | 404 |
| 1002 | 虚拟机操作失败 | 500 |
| 1003 | 虚拟机已在运行 | 409 |
| 1004 | 资源不足 | 507 |
| 2001 | 应用不存在 | 404 |
| 2002 | 应用启动失败 | 500 |
| 3001 | 配置错误 | 400 |
| 3002 | 权限不足 | 403 |
| 4001 | 系统错误 | 500 |

### 5.2 错误响应格式

```json
{
  "error": {
    "code": 1001,
    "message": "虚拟机不存在",
    "details": "未找到名为 'nonexistent' 的虚拟机"
  },
  "success": false
}
```

## 6. 集成示例

### 6.1 Node.js 客户端示例

```javascript
const axios = require('axios');

const apiClient = axios.create({
  baseURL: 'http://localhost:8080/api/v1',
  headers: {
    'Content-Type': 'application/json'
  }
});

// 启动虚拟机
async function startVm(vmName) {
  try {
    const response = await apiClient.post(`/vms/${vmName}/start`);
    return response.data;
  } catch (error) {
    console.error('启动虚拟机失败:', error.response.data);
    throw error;
  }
}

// 启动应用
async function startApp(appName) {
  try {
    const response = await apiClient.post('/apps/start', {
      appId: appName
    });
    return response.data;
  } catch (error) {
    console.error('启动应用失败:', error.response.data);
    throw error;
  }
}
```

### 6.2 Python 客户端示例

```python
import requests

class WinBoatClient:
    def __init__(self, base_url='http://localhost:8080/api/v1'):
        self.base_url = base_url
        self.session = requests.Session()
    
    def get_vms(self):
        response = self.session.get(f"{self.base_url}/vms")
        response.raise_for_status()
        return response.json()
    
    def start_vm(self, vm_id):
        response = self.session.post(f"{self.base_url}/vms/{vm_id}/start")
        response.raise_for_status()
        return response.json()
    
    def get_metrics(self):
        response = self.session.get(f"{self.base_url}/metrics")
        response.raise_for_status()
        return response.json()

# 使用示例
client = WinBoatClient()
vms = client.get_vms()
print(f"虚拟机数量: {vms['total']}")
```

## 7. API 版本控制

WinBoat-Zig 使用 URL 路径版本控制。当前稳定版本为 `v1`。

API 变更政策：

1. **向后兼容更改**：在同一主要版本内（如 v1）的更新保证向后兼容
2. **破坏性更改**：破坏性更改将导致新的主要版本（如 v2）
3. **废弃政策**：废弃的 API 在移除前至少保留两个次要版本

---

*本文档最后更新时间：2025-12-02*

*版权所有 © 2025 WinBoat-Zig 项目 - 木兰宽松许可证 2.0 (MulanPSL-2.0)*