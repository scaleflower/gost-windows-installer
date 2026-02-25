# GOST Windows 安装脚本 - 开发日志

## 项目概述

为 Windows 平台创建 GOST 端口转发工具的一键安装脚本，支持通过 gost-ui 进行可视化管理。

**仓库地址**: https://github.com/scaleflower/gost-windows-installer

---

## 2025-02-25 开发记录

### 初始需求

1. 在 Windows 跳板机上安装 GOST
2. 默认配置 API 服务（端口 8090）供 gost-ui 管理
3. 配置文件使用 JSON 格式（与 gost-ui 兼容）
4. 支持作为 Windows 服务运行

### 完成的工作

#### 1. 创建安装脚本

**文件**: `install-en.ps1`

**功能特性**:
- 自动检测系统架构 (x64/x86/ARM64)
- 从 GitHub 下载最新版 GOST
- 自动生成 JSON 格式配置文件
- 配置防火墙规则
- 添加到系统 PATH
- 可选安装为 Windows 服务

#### 2. 服务管理方式

GOST 内置使用 `judwhite/go-svc` 库，原生支持 Windows 服务，无需 NSSM 等第三方工具。

**服务管理命令**:
```cmd
# 启动
net start GostForward

# 停止
net stop GostForward

# 卸载
sc.exe delete GostForward
```

#### 3. 交互式菜单系统

提供友好的交互式菜单：

```
========================================
      GOST Windows Installer
========================================

Select an option:
  1. Install GOST
  2. Uninstall GOST
  3. Check Update
  4. Exit
```

**安装子菜单**:
- Full Install - 下载最新版本并配置服务
- Service Only - 使用已有文件仅安装服务

#### 4. 卸载功能

完整卸载包括：
- 停止并删除 Windows 服务
- 删除防火墙规则
- 删除安装目录
- 从系统 PATH 移除
- 可选保留配置文件备份

#### 5. 自动更新功能

检查更新时发现新版本可自动更新：
- 自动备份当前版本
- 下载并安装新版本
- 自动重启服务

#### 6. 编码问题解决

**问题**: Windows PowerShell 5.1 对 UTF-8 编码的处理存在兼容性问题，包含中文的脚本文件会被错误解析。

**解决方案**: 创建纯 ASCII 字符的英文版脚本 `install-en.ps1`，完全避免编码问题。

---

## 生成的默认配置

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

---

## 使用方式

### 一键安装

```powershell
irm https://raw.githubusercontent.com/scaleflower/gost-windows-installer/main/install-en.ps1 -OutFile $env:TEMP\install.ps1
PowerShell -ExecutionPolicy Bypass -File $env:TEMP\install.ps1
```

### 命令行参数

```powershell
# 下载
irm https://raw.githubusercontent.com/scaleflower/gost-windows-installer/main/install-en.ps1 -OutFile install.ps1

# 安装
PowerShell -ExecutionPolicy Bypass -File install.ps1 install

# 卸载
PowerShell -ExecutionPolicy Bypass -File install.ps1 uninstall

# 检查更新
PowerShell -ExecutionPolicy Bypass -File install.ps1 update
```

---

## 技术要点

### 架构检测

使用 Windows 环境变量检测系统架构：

| 环境变量 | 值 | 映射到 |
|----------|-----|--------|
| PROCESSOR_ARCHITEW6432 | 存在 | amd64 (WoW64) |
| PROCESSOR_ARCHITECTURE | AMD64 | amd64 |
| PROCESSOR_ARCHITECTURE | x86 | 386 |
| PROCESSOR_ARCHITECTURE | ARM64 | arm64 |

### 下载链接构造

直接使用 GitHub 标准下载 URL 格式：

```
https://github.com/go-gost/gost/releases/download/v3.2.6/gost_3.2.6_windows_amd64.zip
```

### 服务配置

使用 `sc.exe` 创建服务，并配置故障恢复：

```cmd
sc.exe create GostForward binPath= "C:\gost\gost.exe -C C:\gost\config.json" start= auto
sc.exe failure GostForward reset= 86400 actions= restart/5000/restart/10000/restart/20000
```

---

## 相关项目

| 项目 | 地址 |
|------|------|
| GOST | https://github.com/go-gost/gost |
| gost-ui | https://github.com/go-gost/gost-ui |

---

## Git 提交历史

- `a5afde5` - feat: add English version without Chinese characters
- `b67b0df` - fix: 添加 UTF-8 BOM 以兼容 Windows PowerShell 5.1
- `9c1943f` - docs: 更新一键安装命令，改为先下载再执行
- `8f13f04` - fix: 重写脚本，简化逻辑修复执行问题
- `c79187b` - fix: 简化下载逻辑，直接构造下载链接
- `29c5319` - fix: 修复 .Tag 属性访问错误
- `3786828` - fix: 退出选项使用 return 而非 exit
- `6fb73d4` - debug: 添加更详细的调试信息
- `631eb96` - fix: 修复 x86 架构检测问题
- `d6ce7a7` - fix: 修复 Windows 文件名匹配模式
- `ac4f947` - feat: 检查更新支持自动更新
- `3ef885c` - fix: 直接返回 GitHub API 原始响应

---

## 待优化事项

- [ ] 添加代理下载支持（用于国内网络环境）
- [ ] 添加离线安装包支持
- [ ] 支持多版本管理
- [ ] 添加配置文件导入/导出功能
