# WinBoat-Zig 使用指南

本文档提供了 WinBoat-Zig 的详细使用说明，帮助用户快速上手并充分利用其功能。

## 快速开始

### 安装与配置

1. **系统要求**
   - Linux 系统（推荐 Ubuntu 22.04+ 或 Fedora 36+）
   - QEMU/KVM 虚拟化支持
   - 至少 4GB RAM（推荐 8GB+）
   - 至少 20GB 可用磁盘空间

2. **安装必要的依赖**

   ```bash
   # Ubuntu/Debian
   sudo apt update
   sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-manager

   # Fedora
   sudo dnf install -y @virtualization
   ```

3. **将用户添加到 KVM 组**

   ```bash
   sudo usermod -aG kvm $USER
   sudo usermod -aG libvirt $USER
   # 注销并重新登录以应用更改
   ```

4. **构建 WinBoat-Zig**

   ```bash
   # 确保已安装 Zig 0.11.0+
   zig version

   # 编译项目
   cd /path/to/Uya/apps/winboat-zig
   zig build -Doptimize=ReleaseSafe
   ```

## 基本操作

### 启动服务

```bash
# 启动 WinBoat 服务
zig-out/bin/winboat start

# 查看服务状态
zig-out/bin/winboat status
```

### 虚拟机管理

#### 列出虚拟机

```bash
zig-out/bin/winboat vm list
```

#### 启动虚拟机

```bash
zig-out/bin/winboat vm start windows11
```

#### 停止虚拟机

```bash
# 优雅停止（等待操作系统关闭）
zig-out/bin/winboat vm stop windows11

# 强制关闭（相当于断电）
zig-out/bin/winboat vm stop windows11 --force
```

#### 暂停/恢复虚拟机

```bash
# 暂停虚拟机
zig-out/bin/winboat vm pause windows11

# 恢复虚拟机
zig-out/bin/winboat vm resume windows11
```

#### 创建新虚拟机

```bash
zig-out/bin/winboat vm create \
  --name windows11 \
  --disk-size 50 \
  --memory 8192 \
  --cpus 4 \
  --iso /path/to/windows11.iso
```

### 应用程序管理

#### 列出可用应用

```bash
# 列出所有可用的 Windows 应用
zig-out/bin/winboat app list

# 按名称搜索应用
zig-out/bin/winboat app list --search "notepad"
```

#### 启动应用

```bash
# 启动指定应用
zig-out/bin/winboat app start "Microsoft Word"

# 带参数启动应用
zig-out/bin/winboat app start "Notepad" --args "/path/to/file.txt"
```

#### 管理运行中的应用

```bash
# 列出正在运行的应用
zig-out/bin/winboat app running

# 关闭应用
zig-out/bin/winboat app stop <app-id>

# 强制终止应用
zig-out/bin/winboat app kill <app-id>
```

### 系统监控

#### 查看系统指标

```bash
# 实时查看系统资源使用情况
zig-out/bin/winboat metrics

# 以 JSON 格式导出指标
zig-out/bin/winboat metrics --json > metrics.json
```

#### 日志管理

```bash
# 查看最新日志
zig-out/bin/winboat log

# 导出全部日志
zig-out/bin/winboat log export --output winboat-logs.zip

# 设置日志级别
zig-out/bin/winboat config set log.level debug
```

## 高级功能

### 网络配置

#### 创建网络桥接

```bash
# 创建新的网络桥接
zig-out/bin/winboat network create bridge0 --type bridge

# 列出所有网络配置
zig-out/bin/winboat network list
```

### 快照管理

```bash
# 创建虚拟机快照
zig-out/bin/winboat snapshot create windows11 --name "before-update"

# 列出快照
zig-out/bin/winboat snapshot list windows11

# 恢复快照
zig-out/bin/winboat snapshot restore windows11 "before-update"

# 删除快照
zig-out/bin/winboat snapshot delete windows11 "before-update"
```

### 资源限制设置

```bash
# 设置虚拟机资源限制
zig-out/bin/winboat vm set-limits windows11 \
  --cpu-max 2 \
  --memory-max 4096 \
  --disk-iops 1000 \
  --network-bandwidth 100
```

## 排错指南

### 常见问题排查

#### 虚拟机无法启动

1. **检查 KVM 支持**
   ```bash
   kvm-ok
   # 或
   lsmod | grep kvm
   ```

2. **查看详细日志**
   ```bash
   zig-out/bin/winboat log --filter vm --level error
   ```

3. **检查磁盘空间**
   ```bash
   df -h
   ```

#### 应用启动失败

1. **验证 RDP 连接**
   ```bash
   zig-out/bin/winboat diagnostics rdp-connect
   ```

2. **检查 Guest Server 状态**
   ```bash
   zig-out/bin/winboat service status guest-server
   ```

3. **验证应用是否已安装**
   ```bash
   zig-out/bin/winboat app info "应用名称"
   ```

### 系统诊断

```bash
# 运行完整的系统诊断
zig-out/bin/winboat diagnostics full

# 生成诊断报告
zig-out/bin/winboat diagnostics report --output diag-report.zip
```

## 最佳实践

### 性能优化

1. **使用固态驱动器（SSD）存储虚拟机镜像**
2. **为虚拟机分配足够但不过度的内存（推荐至少 4GB）**
3. **在多核系统上，为虚拟机分配物理核心数的 50-75%**
4. **使用 VirtIO 驱动提高 I/O 性能**

### 安全建议

1. **定期更新 Windows 虚拟机中的操作系统和应用**
2. **配置防火墙规则限制不必要的网络访问**
3. **启用 Guest Server 认证功能**
4. **定期创建虚拟机快照**

### 维护计划

1. **每周进行一次系统更新检查**
2. **每月清理不需要的快照和旧日志**
3. **每季度检查磁盘空间并清理临时文件**
4. **定期备份重要虚拟机数据**

## 附录

### 命令行参数速查表

| 命令 | 子命令 | 常用选项 | 描述 |
|------|--------|----------|------|
| vm | create | --name, --disk-size, --memory | 创建新虚拟机 |
| vm | start | --wait | 启动虚拟机 |
| vm | stop | --force | 停止虚拟机 |
| app | start | --args | 启动应用程序 |
| snapshot | create | --name | 创建虚拟机快照 |
| config | set | key value | 设置配置项 |
| log | export | --output | 导出日志文件 |

### 配置文件位置

- 主配置：`~/.config/winboat/config.yaml`
- 虚拟机配置：`~/.config/winboat/vms/`
- 应用缓存：`~/.cache/winboat/apps/`
- 日志文件：`~/.local/share/winboat/logs/`

---

*本文档最后更新时间：2025-12-02*