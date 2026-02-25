# =============================================================================
# GOST Windows 安装脚本
# 用途: 在 Windows 系统上自动下载、安装并配置 GOST
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

# 检测系统架构
function Get-SystemArchitecture {
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    switch ($arch) {
        "X64"   { return "amd64" }
        "Arm64" { return "arm64" }
        "X86"   { return "386" }
        default {
            Write-ColorOutput "不支持的系统架构: $arch" "Red"
            exit 1
        }
    }
}

# 获取最新版本信息
function Get-LatestGostVersion {
    try {
        Write-ColorOutput "正在获取 GOST 最新版本信息..." "Cyan"
        $apiUrl = "https://api.github.com/repos/$GITHUB_REPO/releases/latest"
        $response = Invoke-RestMethod -Uri $apiUrl -Headers @{"Accept"="application/vnd.github.v3+json"}
        return @{
            Tag = $response.tag_name
            Assets = $response.assets
        }
    } catch {
        Write-ColorOutput "获取版本信息失败: $_" "Red"
        exit 1
    }
}

# 下载 GOST
function Download-Gost {
    param(
        [string]$Version,
        [string]$Architecture
    )

    $zipPattern = "gost.*windows-$Architecture.*\.zip"

    foreach ($asset in $Version.Assets) {
        if ($asset.name -match $zipPattern) {
            $downloadUrl = $asset.browser_download_url
            break
        }
    }

    if (-not $downloadUrl) {
        Write-ColorOutput "未找到匹配 Windows $Architecture 的版本" "Red"
        exit 1
    }

    # 创建下载目录
    New-Item -Path $DOWNLOAD_DIR -ItemType Directory -Force | Out-Null
    $zipFile = "$DOWNLOAD_DIR\gost.zip"

    try {
        Write-ColorOutput "正在下载 GOST $($Version.Tag)..." "Cyan"
        Write-ColorOutput "下载地址: $downloadUrl" "Gray"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile -UseBasicParsing
        return $zipFile
    } catch {
        Write-ColorOutput "下载失败: $_" "Red"
        exit 1
    }
}

# 解压并安装
function Install-Gost {
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
        } else {
            Write-ColorOutput "未找到 gost.exe 文件" "Red"
            exit 1
        }

    } catch {
        Write-ColorOutput "安装失败: $_" "Red"
        exit 1
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
    } catch {
        Write-ColorOutput "创建配置文件失败: $_" "Red"
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
        } else {
            Write-ColorOutput "创建服务失败: $result" "Red"
            throw "服务创建失败"
        }
    } catch {
        Write-ColorOutput "安装服务失败: $_" "Red"
        throw
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
    } catch {
        Write-ColorOutput "配置防火墙规则失败: $_" "Yellow"
        Write-ColorOutput "请手动配置防火墙允许端口 $ApiPort" "Yellow"
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
    } catch {
        Write-ColorOutput "添加 PATH 失败: $_" "Yellow"
    }
}

# =============================================================================
# 主程序
# =============================================================================

Write-ColorOutput "`n========================================" "Cyan"
Write-ColorOutput "      GOST Windows 安装脚本" "Cyan"
Write-ColorOutput "========================================`n" "Cyan"

try {
    # 1. 获取最新版本
    $versionInfo = Get-LatestGostVersion
    Write-ColorOutput "最新版本: $($versionInfo.Tag)" "Green"

    # 2. 检测架构
    $architecture = Get-SystemArchitecture
    Write-ColorOutput "系统架构: $architecture" "Green"

    # 3. 下载
    $zipFile = Download-Gost -Version $versionInfo -Architecture $architecture

    # 4. 安装
    Install-Gost -ZipFile $zipFile

    # 5. 生成配置文件
    New-GostConfig

    # 6. 配置防火墙
    Set-FirewallRule -ApiPort 8090

    # 7. 添加到 PATH
    Add-ToPath -Path $INSTALL_DIR

    # 8. 询问是否安装为服务
    Write-ColorOutput "`n是否将 GOST 安装为 Windows 服务? (Y/N)" "Yellow"
    $installService = Read-Host

    if ($installService -eq "Y" -or $installService -eq "y") {
        Install-GostService -ExePath "$INSTALL_DIR\gost.exe" -ConfigPath $CONFIG_FILE
        Write-ColorOutput "`n是否立即启动服务? (Y/N)" "Yellow"
        $startService = Read-Host
        if ($startService -eq "Y" -or $startService -eq "y") {
            Start-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
            Write-ColorOutput "服务已启动" "Green"
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

} catch {
    Write-ColorOutput "`n安装过程中发生错误: $_" "Red"
    exit 1
}
