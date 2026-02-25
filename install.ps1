# =============================================================================
# GOST Windows 安装/卸载脚本
# 用途: 在 Windows 系统上自动下载、安装、卸载 GOST
# 使用: 以管理员身份运行 PowerShell -ExecutionPolicy Bypass -File install.ps1
# =============================================================================

#Requires -RunAsAdministrator

# 配置参数
$GITHUB_REPO = "go-gost/gost"
$INSTALL_DIR = "C:\gost"
$CONFIG_FILE = "$INSTALL_DIR\config.json"
$DOWNLOAD_DIR = "$env:TEMP\gost_install"
$SERVICE_NAME = "GostForward"

# 颜色输出函数
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# 显示主菜单
function Show-MainMenu {
    Clear-Host
    Write-ColorOutput "`n========================================" "Cyan"
    Write-ColorOutput "      GOST Windows 安装程序" "Cyan"
    Write-ColorOutput "========================================`n" "Cyan"

    Write-ColorOutput "请选择操作:" "Yellow"
    Write-Host "  1. 安装 GOST"
    Write-Host "  2. 卸载 GOST"
    Write-Host "  3. 检查更新"
    Write-Host "  4. 退出"
    Write-Host ""

    $choice = Read-Host "请输入选项 (1-4)"
    return $choice
}

# 显示安装菜单
function Show-InstallMenu {
    Clear-Host
    Write-ColorOutput "`n========================================" "Cyan"
    Write-ColorOutput "        安装选项" "Cyan"
    Write-ColorOutput "========================================`n" "Cyan"

    Write-ColorOutput "请选择安装方式:" "Yellow"
    Write-Host "  1. 完整安装 (下载最新版本 + 安装服务)"
    Write-Host "  2. 仅安装服务 (使用已有文件)"
    Write-Host "  3. 返回主菜单"
    Write-Host ""

    $choice = Read-Host "请输入选项 (1-3)"
    return $choice
}

# 检测系统架构
function Get-SystemArchitecture {
    # 获取处理器架构
    $processorArch = $env:PROCESSOR_ARCHITECTURE
    $archW64 = $env:PROCESSOR_ARCHITEW6432

    Write-ColorOutput "检测系统信息..." "Cyan"
    Write-ColorOutput "  PROCESSOR_ARCHITECTURE: $processorArch" "Gray"
    Write-ColorOutput "  PROCESSOR_ARCHITEW6432: $archW64" "Gray"

    # 判断架构
    if ($archW64) {
        # 64位系统上的32位进程
        Write-ColorOutput "  检测结果: amd64 (通过 WoW64)" "Green"
        return "amd64"
    }

    switch ($processorArch) {
        "AMD64" {
            Write-ColorOutput "  检测结果: amd64" "Green"
            return "amd64"
        }
        "IA64" {
            Write-ColorOutput "  检测结果: amd64" "Green"
            return "amd64"
        }
        "x86" {
            Write-ColorOutput "  检测结果: 386" "Green"
            return "386"
        }
        "ARM64" {
            Write-ColorOutput "  检测结果: arm64" "Green"
            return "arm64"
        }
        default {
            # 尝试使用 RuntimeInformation
            try {
                $runtimeArch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
                Write-ColorOutput "  RuntimeArchitecture: $runtimeArch" "Gray"

                switch ($runtimeArch) {
                    "X64" {
                        Write-ColorOutput "  检测结果: amd64" "Green"
                        return "amd64"
                    }
                    "Arm64" {
                        Write-ColorOutput "  检测结果: arm64" "Green"
                        return "arm64"
                    }
                    "X86" {
                        Write-ColorOutput "  检测结果: 386" "Green"
                        return "386"
                    }
                    default {
                        Write-ColorOutput "不支持的系统架构: $runtimeArch" "Red"
                        return $null
                    }
                }
            } catch {
                Write-ColorOutput "无法检测系统架构" "Red"
                return $null
            }
        }
    }
}

# 获取最新版本信息
function Get-LatestGostVersion {
    try {
        Write-ColorOutput "正在获取 GOST 最新版本信息..." "Cyan"
        $apiUrl = "https://api.github.com/repos/$GITHUB_REPO/releases/latest"
        $response = Invoke-RestMethod -Uri $apiUrl -Headers @{"Accept"="application/vnd.github.v3+json"}

        # 直接返回原始 response，确保原始属性可访问
        Write-ColorOutput "获取到 $($response.assets.Count) 个发布文件" "Gray"
        return $response
    } catch {
        Write-ColorOutput "获取版本信息失败: $_" "Red"
        return $null
    }
}

# 下载 GOST
function Download-Gost {
    param(
        [string]$Version,
        [string]$Architecture
    )

    $zipPattern = "gost.*windows_$Architecture.*\.zip"
    Write-ColorOutput "正在匹配 $Architecture 版本..." "Cyan"

    $downloadUrl = $null

    # 先尝试从 Assets 数组中查找
    if ($Version.assets -and $Version.assets.Count -gt 0) {
        Write-ColorOutput "Assets 数量: $($Version.assets.Count)" "Gray"

        foreach ($asset in $Version.assets) {
            # PSObject 需要使用成员访问
            $assetName = $asset.PSObject.Properties.Match('name').Value
            if (-not $assetName) {
                $assetName = $asset.name
            }

            if ($assetName -match $zipPattern) {
                $downloadUrl = $asset.PSObject.Properties.Match('browser_download_url').Value
                if (-not $downloadUrl) {
                    $downloadUrl = $asset.browser_download_url
                }
                Write-ColorOutput "找到匹配: $assetName" "Green"
                break
            }
        }
    }

    if (-not $downloadUrl) {
        Write-ColorOutput "从 API 获取失败，尝试直接构造下载链接..." "Yellow"

        # 备用方案：直接构造下载链接
        $versionTag = $Version.tag_name -replace '^v', ''
        $downloadUrl = "https://github.com/$GITHUB_REPO/releases/download/$($Version.tag_name)/gost_${versionTag}_windows_${Architecture}.zip"
        Write-ColorOutput "构造链接: $downloadUrl" "Gray"

        # 测试链接是否有效
        try {
            $testResponse = Invoke-WebRequest -Uri $downloadUrl -Method Head -UseBasicParsing -ErrorAction Stop
            Write-ColorOutput "链接有效" "Green"
        } catch {
            Write-ColorOutput "链接无效，尝试其他架构..." "Yellow"

            # 列出所有可能的下载链接
            Write-ColorOutput "可用的 Windows 版本:" "Cyan"
            Write-Host "  https://github.com/$GITHUB_REPO/releases/download/$($Version.tag_name)/gost_${versionTag}_windows_386.zip" "Gray"
            Write-Host "  https://github.com/$GITHUB_REPO/releases/download/$($Version.tag_name)/gost_${versionTag}_windows_amd64.zip" "Gray"
            Write-Host "  https://github.com/$GITHUB_REPO/releases/download/$($Version.tag_name)/gost_${versionTag}_windows_arm64.zip" "Gray"

            return $null
        }
    }

    # 创建下载目录
    New-Item -Path $DOWNLOAD_DIR -ItemType Directory -Force | Out-Null
    $zipFile = "$DOWNLOAD_DIR\gost.zip"

    try {
        Write-ColorOutput "正在下载 GOST $($Version.tag_name)..." "Cyan"
        Write-ColorOutput "下载地址: $downloadUrl" "Gray"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile -UseBasicParsing
        return $zipFile
    } catch {
        Write-ColorOutput "下载失败: $_" "Red"
        return $null
    }
}

# 解压并安装
function Install-GostBinary {
    param([string]$ZipFile)

    try {
        Write-ColorOutput "正在解压文件..." "Cyan"
        Expand-Archive -Path $ZipFile -DestinationPath $DOWNLOAD_DIR -Force

        # 创建安装目录
        New-Item -Path $INSTALL_DIR -ItemType Directory -Force | Out-Null

        # 复制可执行文件
        $exeSource = Get-ChildItem -Path $DOWNLOAD_DIR -Filter "gost.exe" -Recurse | Select-Object -First 1
        if ($exeSource) {
            Copy-Item -Path $exeSource.FullName -Destination "$INSTALL_DIR\gost.exe" -Force
            Write-ColorOutput "已安装到: $INSTALL_DIR\gost.exe" "Green"
            return $true
        } else {
            Write-ColorOutput "未找到 gost.exe 文件" "Red"
            return $false
        }

    } catch {
        Write-ColorOutput "安装失败: $_" "Red"
        return $false
    }
}

# 生成默认配置文件 (JSON 格式，与 gost-ui 保持一致)
function New-GostConfig {
    $configContent = @{
        services = @(
            @{
                name = "socks5-proxy"
                addr = ":10800"
                handler = @{
                    type = "socks5"
                }
                listener = @{
                    type = "tcp"
                }
            }
        )
        api = @{
            addr = "0.0.0.0:8090"
        }
    } | ConvertTo-Json -Depth 10

    try {
        Set-Content -Path $CONFIG_FILE -Value $configContent -Encoding UTF8
        Write-ColorOutput "配置文件已创建: $CONFIG_FILE (JSON格式)" "Green"
        return $true
    } catch {
        Write-ColorOutput "创建配置文件失败: $_" "Red"
        return $false
    }
}

# 创建 Windows 服务
# GOST 内置使用 judwhite/go-svc，可直接注册为 Windows 服务
function Install-GostService {
    param([string]$ExePath, [string]$ConfigPath)

    try {
        Write-ColorOutput "正在安装 Windows 服务..." "Cyan"
        $serviceName = $SERVICE_NAME

        # 删除已存在的服务
        $existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($existingService) {
            Write-ColorOutput "检测到已存在的服务，正在删除..." "Yellow"
            Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
            sc.exe delete $serviceName | Out-Null
            Start-Sleep -Seconds 2
        }

        # 创建服务 (GOST 内置支持 Windows 服务模式)
        $binPath = "`"$ExePath`" -C `"$ConfigPath`""
        $result = sc.exe create $serviceName binPath= $binPath start= auto DisplayName= "GOST Port Forwarding Service" 2>&1
        if ($LASTEXITCODE -eq 0) {
            sc.exe description $serviceName "GOST 端口转发服务 - 内置 go-svc 支持，由 gost-ui 管理" | Out-Null

            # 配置服务恢复选项
            sc.exe failure $serviceName reset= 86400 actions= restart/5000/restart/10000/restart/20000 | Out-Null

            Write-ColorOutput "服务已安装: $serviceName" "Green"
            Write-ColorOutput "使用以下命令管理服务:" "Cyan"
            Write-Host "  启动: net start $serviceName" -ForegroundColor Gray
            Write-Host "  停止: net stop $serviceName" -ForegroundColor Gray
            Write-Host "  卸载: sc.exe delete $serviceName" -ForegroundColor Gray
            return $true
        } else {
            Write-ColorOutput "创建服务失败: $result" "Red"
            return $false
        }
    } catch {
        Write-ColorOutput "安装服务失败: $_" "Red"
        return $false
    }
}

# 配置防火墙规则
function Set-FirewallRule {
    param([int]$ApiPort = 8090)

    try {
        Write-ColorOutput "配置防火墙规则..." "Cyan"

        # 删除旧规则
        Remove-NetFirewallRule -DisplayName "GOST API" -ErrorAction SilentlyContinue
        Remove-NetFirewallRule -DisplayName "GOST Service" -ErrorAction SilentlyContinue

        # 添加新规则
        New-NetFirewallRule -DisplayName "GOST API" -Direction Inbound -LocalPort $ApiPort -Protocol TCP -Action Allow | Out-Null
        Write-ColorOutput "防火墙规则已添加: 允许 TCP 端口 $ApiPort" "Green"
        return $true
    } catch {
        Write-ColorOutput "配置防火墙规则失败: $_" "Yellow"
        Write-ColorOutput "请手动配置防火墙允许端口 $ApiPort" "Yellow"
        return $false
    }
}

# 清理临时文件
function Remove-TempFiles {
    if (Test-Path $DOWNLOAD_DIR) {
        Remove-Item -Path $DOWNLOAD_DIR -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# 添加到环境变量
function Add-ToPath {
    param([string]$Path)

    try {
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($currentPath -notlike "*$Path*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$Path", "Machine")
            Write-ColorOutput "已添加到系统 PATH: $Path" "Green"
            Write-ColorOutput "请重启终端以生效" "Yellow"
        } else {
            Write-ColorOutput "PATH 已包含: $Path" "Gray"
        }
        return $true
    } catch {
        Write-ColorOutput "添加 PATH 失败: $_" "Yellow"
        return $false
    }
}

# 从环境变量移除
function Remove-FromPath {
    param([string]$Path)

    try {
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($currentPath -like "*$Path*") {
            $newPath = ($currentPath -split ';' | Where-Object { $_ -ne $Path }) -join ';'
            [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
            Write-ColorOutput "已从系统 PATH 移除: $Path" "Green"
        } else {
            Write-ColorOutput "PATH 中未找到: $Path" "Gray"
        }
        return $true
    } catch {
        Write-ColorOutput "移除 PATH 失败: $_" "Yellow"
        return $false
    }
}

# 完整安装
function Install-Full {
    Clear-Host
    Write-ColorOutput "`n========================================" "Cyan"
    Write-ColorOutput "      正在安装 GOST" "Cyan"
    Write-ColorOutput "========================================`n" "Cyan"

    # 1. 获取最新版本
    $versionInfo = Get-LatestGostVersion
    if (-not $versionInfo) {
        Write-ColorOutput "`n按任意键返回..." "Yellow"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return $false
    }
    Write-ColorOutput "最新版本: $($versionInfo.Tag)" "Green"

    # 2. 检测架构
    $architecture = Get-SystemArchitecture
    if (-not $architecture) {
        Write-ColorOutput "`n按任意键返回..." "Yellow"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return $false
    }
    Write-ColorOutput "系统架构: $architecture" "Green"

    # 3. 下载
    $zipFile = Download-Gost -Version $versionInfo -Architecture $architecture
    if (-not $zipFile) {
        Write-ColorOutput "`n按任意键返回..." "Yellow"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return $false
    }

    # 4. 安装
    if (-not (Install-GostBinary -ZipFile $zipFile)) {
        Write-ColorOutput "`n按任意键返回..." "Yellow"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return $false
    }

    # 5. 生成配置文件
    New-GostConfig

    # 6. 配置防火墙
    Set-FirewallRule -ApiPort 8090

    # 7. 添加到 PATH
    Add-ToPath -Path $INSTALL_DIR

    # 8. 安装服务
    Write-ColorOutput "`n是否将 GOST 安装为 Windows 服务? (Y/N)" "Yellow"
    $installService = Read-Host

    if ($installService -eq "Y" -or $installService -eq "y") {
        if (Install-GostService -ExePath "$INSTALL_DIR\gost.exe" -ConfigPath $CONFIG_FILE) {
            Write-ColorOutput "`n是否立即启动服务? (Y/N)" "Yellow"
            $startService = Read-Host
            if ($startService -eq "Y" -or $startService -eq "y") {
                Start-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
                Write-ColorOutput "服务已启动" "Green"
            }
        }
    }

    # 清理
    Remove-TempFiles

    Write-ColorOutput "`n========================================" "Green"
    Write-ColorOutput "        安装完成!" "Green"
    Write-ColorOutput "========================================`n" "Green"
    Write-ColorOutput "安装目录: $INSTALL_DIR" "White"
    Write-ColorOutput "配置文件: $CONFIG_FILE" "White"
    Write-ColorOutput "API 地址: http://localhost:8090" "White"
    Write-Host "`n手动运行命令:" -ForegroundColor Cyan
    Write-Host "  cd $INSTALL_DIR" -ForegroundColor Gray
    Write-Host "  .\gost.exe -C config.json" -ForegroundColor Gray

    Write-ColorOutput "`n按任意键返回..." "Yellow"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    return $true
}

# 仅安装服务
function Install-ServiceOnly {
    Clear-Host
    Write-ColorOutput "`n========================================" "Cyan"
    Write-ColorOutput "      正在安装服务" "Cyan"
    Write-ColorOutput "========================================`n" "Cyan"

    # 检查文件是否存在
    if (-not (Test-Path "$INSTALL_DIR\gost.exe")) {
        Write-ColorOutput "错误: 未找到 $INSTALL_DIR\gost.exe" "Red"
        Write-ColorOutput "请先选择完整安装下载 GOST" "Yellow"
        Write-ColorOutput "`n按任意键返回..." "Yellow"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return $false
    }

    # 检查配置文件
    if (-not (Test-Path $CONFIG_FILE)) {
        Write-ColorOutput "未找到配置文件，是否创建默认配置? (Y/N)" "Yellow"
        $createConfig = Read-Host
        if ($createConfig -eq "Y" -or $createConfig -eq "y") {
            New-GostConfig
        } else {
            Write-ColorOutput "`n按任意键返回..." "Yellow"
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return $false
        }
    }

    # 配置防火墙
    Set-FirewallRule -ApiPort 8090

    # 添加到 PATH
    Add-ToPath -Path $INSTALL_DIR

    # 安装服务
    if (Install-GostService -ExePath "$INSTALL_DIR\gost.exe" -ConfigPath $CONFIG_FILE) {
        Write-ColorOutput "`n是否立即启动服务? (Y/N)" "Yellow"
        $startService = Read-Host
        if ($startService -eq "Y" -or $startService -eq "y") {
            Start-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
            Write-ColorOutput "服务已启动" "Green"
        }
    }

    Write-ColorOutput "`n按任意键返回..." "Yellow"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    return $true
}

# 卸载 GOST
function Uninstall-Gost {
    Clear-Host
    Write-ColorOutput "`n========================================" "Yellow"
    Write-ColorOutput "      正在卸载 GOST" "Yellow"
    Write-ColorOutput "========================================`n" "Yellow"

    Write-ColorOutput "警告: 此操作将删除 GOST 及相关配置" "Red"
    Write-ColorOutput "`n确认继续? (Y/N)" "Yellow"
    $confirm = Read-Host

    if ($confirm -ne "Y" -and $confirm -ne "y") {
        Write-ColorOutput "已取消卸载" "Gray"
        Write-ColorOutput "`n按任意键返回..." "Yellow"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return $false
    }

    # 1. 停止并删除服务
    $existingService = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
    if ($existingService) {
        Write-ColorOutput "正在停止服务..." "Cyan"
        Stop-Service -Name $SERVICE_NAME -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1

        Write-ColorOutput "正在删除服务..." "Cyan"
        sc.exe delete $SERVICE_NAME | Out-Null
        Write-ColorOutput "服务已删除" "Green"
    } else {
        Write-ColorOutput "未检测到已安装的服务" "Gray"
    }

    # 2. 删除防火墙规则
    Write-ColorOutput "正在删除防火墙规则..." "Cyan"
    Remove-NetFirewallRule -DisplayName "GOST API" -ErrorAction SilentlyContinue
    Remove-NetFirewallRule -DisplayName "GOST Service" -ErrorAction SilentlyContinue
    Write-ColorOutput "防火墙规则已删除" "Green"

    # 3. 删除安装目录
    if (Test-Path $INSTALL_DIR) {
        Write-ColorOutput "正在删除安装目录: $INSTALL_DIR" "Cyan"
        # 询问是否保留配置文件
        Write-ColorOutput "`n是否保留配置文件 config.json? (Y/N)" "Yellow"
        $keepConfig = Read-Host

        if ($keepConfig -eq "Y" -or $keepConfig -eq "y") {
            # 备份配置文件
            $backupPath = "$env:USERPROFILE\Desktop\gost-config-backup.json"
            Copy-Item -Path $CONFIG_FILE -Destination $backupPath -Force -ErrorAction SilentlyContinue
            if (Test-Path $backupPath) {
                Write-ColorOutput "配置文件已备份到: $backupPath" "Green"
            }
        }
        Remove-Item -Path $INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
        Write-ColorOutput "安装目录已删除" "Green"
    } else {
        Write-ColorOutput "安装目录不存在" "Gray"
    }

    # 4. 从 PATH 移除
    Remove-FromPath -Path $INSTALL_DIR

    Write-ColorOutput "`n========================================" "Green"
    Write-ColorOutput "        卸载完成!" "Green"
    Write-ColorOutput "========================================`n" "Green"

    Write-ColorOutput "按任意键返回..." "Yellow"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    return $true
}

# 检查更新
function Check-Update {
    Clear-Host
    Write-ColorOutput "`n========================================" "Cyan"
    Write-ColorOutput "      检查更新" "Cyan"
    Write-ColorOutput "========================================`n" "Cyan"

    $versionInfo = Get-LatestGostVersion
    if (-not $versionInfo) {
        Write-ColorOutput "`n按任意键返回..." "Yellow"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    Write-ColorOutput "最新版本: $($versionInfo.Tag)" "Green"

    # 检查当前安装的版本
    $currentVersion = $null
    if (Test-Path "$INSTALL_DIR\gost.exe") {
        try {
            $versionOutput = & "$INSTALL_DIR\gost.exe" -V 2>&1
            if ($versionOutput -match "gost ([\d\.]+)") {
                $currentVersion = $matches[1]
            }
            Write-ColorOutput "当前版本: $currentVersion" "Cyan"
        } catch {
            Write-ColorOutput "无法检测当前版本" "Yellow"
        }
    } else {
        Write-ColorOutput "未安装 GOST" "Yellow"
        Write-ColorOutput "`n按任意键返回..." "Yellow"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    $latestVersion = $versionInfo.Tag.TrimStart('v')

    if ($currentVersion -eq $latestVersion) {
        Write-ColorOutput "`n已是最新版本!" "Green"
    } else {
        Write-ColorOutput "`n发现新版本!" "Yellow"
        Write-ColorOutput "当前: $currentVersion -> 最新: $latestVersion" "Cyan"

        Write-ColorOutput "`n是否立即更新? (Y/N)" "Yellow"
        $updateConfirm = Read-Host

        if ($updateConfirm -eq "Y" -or $updateConfirm -eq "y") {
            # 执行更新
            Write-ColorOutput "`n正在更新..." "Cyan"

            # 停止服务
            $existingService = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
            if ($existingService) {
                Write-ColorOutput "正在停止服务..." "Cyan"
                Stop-Service -Name $SERVICE_NAME -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 1
            }

            # 检测架构
            $architecture = Get-SystemArchitecture
            if (-not $architecture) {
                Write-ColorOutput "`n按任意键返回..." "Yellow"
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                return
            }

            # 下载
            $zipFile = Download-Gost -Version $versionInfo -Architecture $architecture
            if (-not $zipFile) {
                Write-ColorOutput "`n按任意键返回..." "Yellow"
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                return
            }

            # 备份旧版本
            $backupDir = "$INSTALL_DIR\backup_$currentVersion"
            if (Test-Path "$INSTALL_DIR\gost.exe") {
                Write-ColorOutput "备份当前版本到: $backupDir" "Cyan"
                New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
                Copy-Item -Path "$INSTALL_DIR\gost.exe" -Destination "$backupDir\gost.exe" -Force
            }

            # 安装新版本
            Write-ColorOutput "安装新版本..." "Cyan"
            Expand-Archive -Path $zipFile -DestinationPath $DOWNLOAD_DIR -Force
            $exeSource = Get-ChildItem -Path $DOWNLOAD_DIR -Filter "gost.exe" -Recurse | Select-Object -First 1
            if ($exeSource) {
                Copy-Item -Path $exeSource.FullName -Destination "$INSTALL_DIR\gost.exe" -Force
                Write-ColorOutput "更新完成!" "Green"
            }

            # 清理临时文件
            Remove-TempFiles

            # 重启服务
            if ($existingService) {
                Write-ColorOutput "正在重启服务..." "Cyan"
                Start-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
                Write-ColorOutput "服务已重启" "Green"
            }

            Write-ColorOutput "`n========================================" "Green"
            Write-ColorOutput "        更新成功!" "Green"
            Write-ColorOutput "========================================`n" "Green"
            Write-ColorOutput "新版本: $latestVersion" "White"
            Write-ColorOutput "备份位置: $backupDir" "Gray"
        }
    }

    Write-ColorOutput "`n按任意键返回..." "Yellow"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# =============================================================================
# 主程序
# =============================================================================

# 检查命令行参数
if ($args.Count -gt 0) {
    $Action = $args[0].ToLower()
    switch ($Action) {
        "install" {
            Install-Full
        }
        "uninstall" {
            Uninstall-Gost
        }
        "update" {
            Check-Update
        }
        default {
            Write-ColorOutput "未知操作: $Action" "Red"
            Write-Host "`n使用方法:" -ForegroundColor Cyan
            Write-Host "  安装: install.ps1 install" -ForegroundColor Gray
            Write-Host "  卸载: install.ps1 uninstall" -ForegroundColor Gray
            Write-Host "  更新: install.ps1 update" -ForegroundColor Gray
            Write-Host "  交互菜单: install.ps1" -ForegroundColor Gray
        }
    }
    return
}

# 交互式菜单模式
do {
    $choice = Show-MainMenu

    switch ($choice) {
        "1" {
            # 安装子菜单
            do {
                $subChoice = Show-InstallMenu
                switch ($subChoice) {
                    "1" { Install-Full }
                    "2" { Install-ServiceOnly }
                    "3" { break }
                }
            } while ($subChoice -ne "3")
        }
        "2" {
            Uninstall-Gost
        }
        "3" {
            Check-Update
        }
        "4" {
            Write-ColorOutput "`n再见!" "Green"
            return
        }
        default {
            Write-ColorOutput "`n无效选项，请重新选择" "Red"
            Start-Sleep -Seconds 1
        }
    }
} while ($true)
