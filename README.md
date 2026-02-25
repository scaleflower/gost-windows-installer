# GOST 端口转发管理脚本

这是一个简化的 GOST 端口转发管理项目，包含 Windows 自动安装脚本，用于快速部署 GOST 及其管理界面。

## 项目简介

本项目提供 Windows 平台下一键安装 GOST 的脚本，自动配置 API 服务以便通过 [gost-ui](https://github.com/go-gost/gost-ui) 进行管理。

## 相关项目

| 项目 | 地址 | 说明 |
|------|------|------|
| **GOST** | https://github.com/go-gost/gost | GO 语言编写的简单、高效的端口转发/隧道工具 |
| **gost-ui** | https://github.com/go-gost/gost-ui | GOST 的 Web 管理界面，支持可视化配置 |

## 快速开始

### 方式一：交互式菜单（推荐）

以管理员身份打开 PowerShell，执行以下命令：

```powershell
# 下载并运行
irm https://raw.githubusercontent.com/scaleflower/gost-windows-installer/main/install.ps1 -OutFile $env:TEMP\install.ps1; PowerShell -ExecutionPolicy Bypass -File $env:TEMP\install.ps1
```

### 方式二：分步执行

```powershell
# 1. 下载脚本
irm https://raw.githubusercontent.com/scaleflower/gost-windows-installer/main/install.ps1 -OutFile $env:TEMP\install.ps1

# 2. 运行脚本
PowerShell -ExecutionPolicy Bypass -File $env:TEMP\install.ps1
```

### 方式三：命令行参数

```powershell
# 下载脚本
irm https://raw.githubusercontent.com/scaleflower/gost-windows-installer/main/install.ps1 -OutFile install.ps1

# 安装
PowerShell -ExecutionPolicy Bypass -File install.ps1 install

# 卸载
PowerShell -ExecutionPolicy Bypass -File install.ps1 uninstall

# 检查更新
PowerShell -ExecutionPolicy Bypass -File install.ps1 update
```

### 安装选项

| 选项 | 说明 |
|------|------|
| 完整安装 | 下载最新版本 + 配置服务 |
| 仅安装服务 | 使用已有文件安装服务 |
| 卸载 | 完全移除 GOST（可选保留配置） |
| 检查更新 | 对比当前版本与最新版本 |

### 生成的默认配置

```json
{
    "services": [
        {
            "name": "socks5-proxy",
            "addr": ":10800",
            "handler": {
                "type": "socks5"
            },
            "listener": {
                "type": "tcp"
            }
        }
    ],
    "api": {
        "addr": "0.0.0.0:8090"
    }
}
```

## 使用方法

### 手动运行 GOST

```cmd
cd C:\gost
gost.exe -C config.json
```

### 使用 gost-ui 管理

1. 在 VPS 上部署 gost-ui
2. 访问 `http://VPS_IP:端口`
3. 添加远程 GOST 服务器：`http://跳板机IP:8090`
4. 在 Web 界面中配置端口映射规则

### Windows 服务管理

GOST 内置使用 [judwhite/go-svc](https://github.com/judwhite/go-svc)，可直接注册为 Windows 服务，无需 NSSM 等第三方工具。

如果安装时选择了创建服务：

```cmd
# 启动服务
net start GostForward

# 停止服务
net stop GostForward

# 卸载服务
sc.exe delete GostForward
```

**注意**：GOST 会自动识别服务模式并正确处理 Windows 的启动/停止信号。

## 配置文件格式

GOST 支持 JSON 和 YAML 两种格式。本脚本默认使用 **JSON 格式**，与 gost-ui 的默认保存格式一致。

如需使用 YAML 格式，可在 gost-ui 设置中选择。

## 注意事项

### 安全建议

1. **API 端口安全**：默认 API 端口 8090 建议仅在内网或通过防火墙限制访问
2. **生产环境**：建议为 API 添加认证
3. **防火墙规则**：仅开放必要的端口

### 配置示例

#### 添加 API 认证

```json
{
    "api": {
        "addr": "0.0.0.0:8090",
        "auth": {
            "username": "admin",
            "password": "your_password"
        }
    }
}
```

#### TCP 端口转发示例

```json
{
    "services": [
        {
            "name": "mysql-forward",
            "addr": ":3307",
            "handler": {
                "type": "tcp"
            },
            "listener": {
                "type": "tcp"
            },
            "forwarder": {
                "nodes": [
                    {
                        "name": "mysql-server",
                        "addr": "192.168.1.100:3306"
                    }
                ]
            }
        }
    ],
    "api": {
        "addr": "0.0.0.0:8090"
    }
}
```

## 目录结构

```
C:\gost\
├── gost.exe          # GOST 可执行文件
└── config.json       # 配置文件
```

## 故障排查

### 服务无法启动

1. 检查配置文件语法：`gost.exe -C config.json -D`（调试模式）
2. 检查端口是否被占用
3. 查看 Windows 事件查看器中的日志

### API 无法访问

1. 检查防火墙规则
2. 确认 GOST 进程正在运行
3. 检查 API 地址配置

## 许可证

本脚本基于 MIT 许可证发布。

GOST 和 gost-ui 请参考其各自的许可证。

---

**更新日期**: 2025-02-25
