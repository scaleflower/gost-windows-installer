# =============================================================================
# GOST Windows Installer/Uninstaller Script
# Purpose: Automatically download, install, uninstall GOST on Windows
# Usage: Run as Administrator - PowerShell -ExecutionPolicy Bypass -File install-en.ps1
# =============================================================================

#Requires -RunAsAdministrator

# Configuration
$GITHUB_REPO = "go-gost/gost"
$INSTALL_DIR = "C:\gost"
$CONFIG_FILE = "$INSTALL_DIR\config.json"
$DOWNLOAD_DIR = "$env:TEMP\gost_install"
$SERVICE_NAME = "GostForward"
$LOG_FILE = "$env:TEMP\gost-install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Detect system language (Chinese or English)
$systemLang = (Get-Culture).TwoLetterISOLanguageName
$IsChineseSystem = ($systemLang -eq "zh") -or ($systemLang -eq "zh-CN") -or ($systemLang -eq "zh-TW")

# Localization strings
$Strings = @{
    # Common
    Back = if ($IsChineseSystem) { "返回" } else { "Back" }
    Continue = if ($IsChineseSystem) { "继续" } else { "Continue" }
    Yes = if ($IsChineseSystem) { "是" } else { "Yes" }
    No = if ($IsChineseSystem) { "否" } else { "No" }

    # Main Menu
    MainTitle = if ($IsChineseSystem) { "GOST Windows 安装程序" } else { "GOST Windows Installer" }
    SelectOption = if ($IsChineseSystem) { "选择操作:" } else { "Select an option:" }
    OptInstall = if ($IsChineseSystem) { "1. 安装 GOST" } else { "1. Install GOST" }
    OptUninstall = if ($IsChineseSystem) { "2. 卸载 GOST" } else { "2. Uninstall GOST" }
    OptUpdate = if ($IsChineseSystem) { "3. 检查更新" } else { "3. Check Update" }
    OptViewLog = if ($IsChineseSystem) { "4. 查看日志" } else { "4. View Log" }
    OptExit = if ($IsChineseSystem) { "5. 退出" } else { "5. Exit" }
    EnterOption = if ($IsChineseSystem) { "输入选项 (1-5): " } else { "Enter option (1-5): " }

    # Install Menu
    InstallTitle = if ($IsChineseSystem) { "安装选项" } else { "Installation Options" }
    SelectInstallType = if ($IsChineseSystem) { "选择安装类型:" } else { "Select installation type:" }
    OptFullInstall = if ($IsChineseSystem) { "1. 完整安装 (下载 + 服务)" } else { "1. Full Install (Download + Service)" }
    OptServiceOnly = if ($IsChineseSystem) { "2. 仅安装服务 (使用已有文件)" } else { "2. Service Only (Use existing files)" }
    OptBackToMain = if ($IsChineseSystem) { "3. 返回主菜单" } else { "3. Back to Main Menu" }
    EnterOption_3 = if ($IsChineseSystem) { "输入选项 (1-3): " } else { "Enter option (1-3): " }

    # Installation
    InstallingTitle = if ($IsChineseSystem) { "正在安装 GOST" } else { "Installing GOST" }
    InstallComplete = if ($IsChineseSystem) { "安装完成!" } else { "Installation Complete!" }
    FetchingVersion = if ($IsChineseSystem) { "正在获取最新 GOST 版本..." } else { "Fetching latest GOST version..." }
    LatestVersion = if ($IsChineseSystem) { "最新版本: " } else { "Latest version: " }
    DetectingSystem = if ($IsChineseSystem) { "正在检测系统..." } else { "Detecting system..." }
    Downloading = if ($IsChineseSystem) { "正在下载 GOST " } else { "Downloading GOST " }
    DownloadCompleted = if ($IsChineseSystem) { "下载完成" } else { "Download completed" }
    ExtractingFiles = if ($IsChineseSystem) { "正在解压文件..." } else { "Extracting files..." }
    InstalledTo = if ($IsChineseSystem) { "已安装到: " } else { "Installed to: " }
    ConfigCreated = if ($IsChineseSystem) { "配置文件已创建: " } else { "Config file created: " }
    FirewallAdded = if ($IsChineseSystem) { "防火墙规则已添加: TCP 端口 " } else { "Firewall rule added: TCP port " }
    AddedToPath = if ($IsChineseSystem) { "已添加到系统 PATH: " } else { "Added to system PATH: " }
    InstallAsService = if ($IsChineseSystem) { "`n是否安装为 Windows 服务? (Y/N)" } else { "`nInstall as Windows service? (Y/N)" }
    StartServiceNow = if ($IsChineseSystem) { "`n现在启动服务? (Y/N)" } else { "`nStart service now? (Y/N)" }
    ServiceStarted = if ($IsChineseSystem) { "服务已启动" } else { "Service started" }
    ServiceInstalled = if ($IsChineseSystem) { "服务已安装: " } else { "Service installed: " }
    PressAnyKey = if ($IsChineseSystem) { "`n按任意键返回..." } else { "`nPress any key to return..." }

    # Uninstall
    UninstallingTitle = if ($IsChineseSystem) { "正在卸载 GOST" } else { "Uninstalling GOST" }
    UninstallComplete = if ($IsChineseSystem) { "卸载完成!" } else { "Uninstall Complete!" }
    UninstallWarning = if ($IsChineseSystem) { "警告: 这将删除 GOST 和配置文件" } else { "Warning: This will remove GOST and configurations" }
    ContinueQuestion = if ($IsChineseSystem) { "`n继续? (Y/N)" } else { "`nContinue? (Y/N)" }
    Cancelled = if ($IsChineseSystem) { "已取消" } else { "Cancelled" }
    StoppingService = if ($IsChineseSystem) { "正在停止服务..." } else { "Stopping service..." }
    ServiceRemoved = if ($IsChineseSystem) { "服务已删除" } else { "Service removed" }
    RemovingFirewall = if ($IsChineseSystem) { "正在删除防火墙规则..." } else { "Removing firewall rules..." }
    FirewallRemoved = if ($IsChineseSystem) { "防火墙规则已删除" } else { "Firewall rules removed" }
    RemovingInstallDir = if ($IsChineseSystem) { "正在删除安装目录: " } else { "Removing install directory: " }
    KeepConfig = if ($IsChineseSystem) { "`n保留配置文件? (Y/N)" } else { "`nKeep config file? (Y/N)" }
    ConfigBackedUp = if ($IsChineseSystem) { "配置已备份到: " } else { "Config backed up to: " }
    InstallDirRemoved = if ($IsChineseSystem) { "安装目录已删除" } else { "Install directory removed" }
    RemovedFromPath = if ($IsChineseSystem) { "已从系统 PATH 移除: " } else { "Removed from system PATH: " }

    # Update
    UpdateTitle = if ($IsChineseSystem) { "检查更新" } else { "Check Update" }
    CurrentVersion = if ($IsChineseSystem) { "当前版本: " } else { "Current version: " }
    CannotDetectVersion = if ($IsChineseSystem) { "无法检测当前版本" } else { "Cannot detect current version" }
    GostNotInstalled = if ($IsChineseSystem) { "GOST 未安装" } else { "GOST not installed" }
    AlreadyUpToDate = if ($IsChineseSystem) { "`n已是最新版本!" } else { "`nAlready up to date!" }
    NewVersionAvailable = if ($IsChineseSystem) { "`n发现新版本!" } else { "`nNew version available!" }
    CurrentToLatest = if ($IsChineseSystem) { "当前: {0} -> 最新: {1}" } else { "Current: {0} -> Latest: {1}" }
    UpdateNow = if ($IsChineseSystem) { "`n现在更新? (Y/N)" } else { "`nUpdate now? (Y/N)" }
    Updating = if ($IsChineseSystem) { "`n正在更新..." } else { "`nUpdating..." }
    BackingUpTo = if ($IsChineseSystem) { "正在备份到: " } else { "Backing up to: " }
    InstallingNewVersion = if ($IsChineseSystem) { "正在安装新版本..." } else { "Installing new version..." }
    UpdateComplete = if ($IsChineseSystem) { "更新完成!" } else { "Update complete!" }
    BackupLocation = if ($IsChineseSystem) { "备份位置: " } else { "Backup location: " }
    RestartingService = if ($IsChineseSystem) { "正在重启服务..." } else { "Restarting service..." }
    ServiceRestarted = if ($IsChineseSystem) { "服务已重启" } else { "Service restarted" }
    NewVersion = if ($IsChineseSystem) { "新版本: " } else { "New version: " }

    # View Log
    ViewLogTitle = if ($IsChineseSystem) { "查看日志文件" } else { "View Log File" }
    NoLogFiles = if ($IsChineseSystem) { "未找到日志文件" } else { "No log files found" }
    CurrentLogFile = if ($IsChineseSystem) { "当前日志文件: " } else { "Current log file: " }
    FoundLogFiles = if ($IsChineseSystem) { "找到 {0} 个日志文件:`n" } else { "Found {0} log file(s):`n" }
    Opening = if ($IsChineseSystem) { "正在打开: " } else { "Opening: " }
    LogContent = if ($IsChineseSystem) { "`n========== 内容: {0} ==========`n" } else { "`n========== Content of {0} ==========`n" }
    EndOfLog = if ($IsChineseSystem) { "`n========== 日志结束 (显示最后 50 行) ==========" } else { "`n========== End of log (showing last 50 lines) ==========" }

    # Defender
    DefenderTitle = if ($IsChineseSystem) { "Windows Defender 检测" } else { "Windows Defender Detection" }
    DefenderActive = if ($IsChineseSystem) { "Windows Defender 实时保护已启用" } else { "Windows Defender real-time protection is ACTIVE" }
    DefenderInterfere = if ($IsChineseSystem) { "这可能会干扰安装 (阻止下载、API 调用等)" } else { "This may interfere with installation (block downloads, API calls, etc.)" }
    DisableDefender = if ($IsChineseSystem) { "`n是否临时禁用 Defender? (Y/N)" } else { "`nDisable Defender temporarily? (Y/N)" }
    DisablingDefender = if ($IsChineseSystem) { "正在禁用 Windows Defender 实时保护..." } else { "Disabling Windows Defender real-time protection..." }
    DefenderDisabled = if ($IsChineseSystem) { "Windows Defender 实时保护已禁用" } else { "Windows Defender real-time protection DISABLED" }
    DefenderAlreadyDisabled = if ($IsChineseSystem) { "Windows Defender 实时监控已被禁用" } else { "Windows Defender real-time monitoring is already disabled" }
    WillRestoreAfter = if ($IsChineseSystem) { "安装完成后会自动恢复" } else { "It will be re-enabled after installation completes" }
    KeepingDefender = if ($IsChineseSystem) { "保持 Defender 启用 (安装可能会失败)" } else { "Keeping Defender enabled (installation may fail)" }
    ReEnablingDefender = if ($IsChineseSystem) { "正在重新启用 Windows Defender 实时保护..." } else { "Re-enabling Windows Defender real-time protection..." }
    DefenderEnabled = if ($IsChineseSystem) { "Windows Defender 实时保护已启用" } else { "Windows Defender real-time protection ENABLED" }

    # Error messages
    Error = if ($IsChineseSystem) { "错误" } else { "Error" }
    Failed = if ($IsChineseSystem) { "失败" } else { "Failed" }
    NotFound = if ($IsChineseSystem) { "未找到" } else { "not found" }
    InvalidOption = if ($IsChineseSystem) { "`n无效选项" } else { "`nInvalid option" }
    Goodbye = if ($IsChineseSystem) { "`n再见!" } else { "`nGoodbye!" }

    # Service
    StartService = if ($IsChineseSystem) { "启动: net start {0}" } else { "Start: net start {0}" }
    StopService = if ($IsChineseSystem) { "停止: net stop {0}" } else { "Stop: net stop {0}" }
    ServiceCommands = if ($IsChineseSystem) { "服务命令:" } else { "Service commands:" }
}

# Initialize log
function Initialize-Log {
    $logDir = Split-Path -Parent $LOG_FILE
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LOG_FILE -Value "========== GOST Installer Log Started at $timestamp =========="
    Write-Host "Log file: $LOG_FILE" -ForegroundColor DarkGray
}

# Color output function with logging
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
    # Also write to log file (without color codes)
    $timestamp = Get-Date -Format "HH:mm:ss"
    Add-Content -Path $LOG_FILE -Value "[$timestamp] $Message"
}

# Write debug info to log
function Write-DebugLog {
    param([string]$Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    Add-Content -Path $LOG_FILE -Value "[$timestamp] DEBUG: $Message"
}

# Disable Windows Defender Real-time Protection temporarily
function Disable-DefenderTemp {
    try {
        Write-ColorOutput "`n========================================" "Yellow"
        Write-ColorOutput "  Windows Defender Detection" "Yellow"
        Write-ColorOutput "========================================`n" "Yellow"

        # Check if Defender is active
        $defenderEnabled = $null
        try {
            $defenderEnabled = Get-MpPreference | Select-Object -ExpandProperty DisableRealtimeMonitoring
        } catch {
            Write-ColorOutput "Cannot check Defender status (may be disabled by policy)" "Yellow"
            return $false
        }

        if (-not $defenderEnabled) {
            Write-ColorOutput "Windows Defender real-time monitoring is already disabled" "Green"
            return $false
        }

        Write-ColorOutput "Windows Defender real-time protection is ACTIVE" "Red"
        Write-ColorOutput "This may interfere with installation (block downloads, API calls, etc.)" "Yellow"
        Write-Host ""
        Write-ColorOutput "Disable Defender temporarily? (Y/N)" "Yellow"
        $disable = Read-Host

        if ($disable -eq "Y" -or $disable -eq "y") {
            Write-ColorOutput "Disabling Windows Defender real-time protection..." "Cyan"
            Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop
            Start-Sleep -Seconds 1
            Write-ColorOutput "Windows Defender real-time protection DISABLED" "Green"
            Write-ColorOutput "It will be re-enabled after installation completes" "Yellow"
            return $true
        } else {
            Write-ColorOutput "Keeping Defender enabled (installation may fail)" "Yellow"
            return $false
        }
    } catch {
        Write-ColorOutput "Failed to disable Defender: $_" "Red"
        Write-ColorOutput "You may need to disable it manually" "Yellow"
        return $false
    }
}

# Enable Windows Defender Real-time Protection
function Enable-Defender {
    try {
        Write-ColorOutput "Re-enabling Windows Defender real-time protection..." "Cyan"
        Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
        Write-ColorOutput "Windows Defender real-time protection ENABLED" "Green"
    } catch {
        Write-ColorOutput "Note: Please manually verify Defender is enabled" "Yellow"
    }
}

# Check Windows Defender status
function Test-DefenderStatus {
    try {
        $preference = Get-MpPreference -ErrorAction Stop
        return -not $preference.DisableRealtimeMonitoring
    } catch {
        return $null
    }
}

# Show main menu
function Show-MainMenu {
    Clear-Host
    Write-ColorOutput "`n========================================" "Cyan"
    Write-ColorOutput $("      {0}" -f $Strings.MainTitle) "Cyan"
    Write-ColorOutput "========================================`n" "Cyan"

    Write-ColorOutput $Strings.SelectOption "Yellow"
    Write-Host $Strings.OptInstall
    Write-Host $Strings.OptUninstall
    Write-Host $Strings.OptUpdate
    Write-Host $Strings.OptViewLog
    Write-Host $Strings.OptExit
    Write-Host ""

    $choice = Read-Host $Strings.EnterOption
    return $choice
}

# Show install menu
function Show-InstallMenu {
    Clear-Host
    Write-ColorOutput "`n========================================" "Cyan"
    Write-ColorOutput $("        {0}" -f $Strings.InstallTitle) "Cyan"
    Write-ColorOutput "========================================`n" "Cyan"

    Write-ColorOutput $Strings.SelectInstallType "Yellow"
    Write-Host $Strings.OptFullInstall
    Write-Host $Strings.OptServiceOnly
    Write-Host $Strings.OptBackToMain
    Write-Host ""

    $choice = Read-Host $Strings.EnterOption_3
    return $choice
}

# Detect system architecture
function Get-SystemArchitecture {
    $processorArch = $env:PROCESSOR_ARCHITECTURE
    $archW64 = $env:PROCESSOR_ARCHITEW6432

    Write-ColorOutput $Strings.DetectingSystem "Cyan"
    Write-ColorOutput "  PROCESSOR_ARCHITECTURE: $processorArch" "Gray"

    if ($archW64) {
        Write-ColorOutput "  Result: amd64" "Green"
        return "amd64"
    }

    switch ($processorArch) {
        "AMD64" {
            Write-ColorOutput "  Result: amd64" "Green"
            return "amd64"
        }
        "x86" {
            Write-ColorOutput "  Result: 386" "Green"
            return "386"
        }
        "ARM64" {
            Write-ColorOutput "  Result: arm64" "Green"
            return "arm64"
        }
        default {
            Write-ColorOutput "Unsupported architecture: $processorArch" "Red"
            return $null
        }
    }
}

# Get latest version info
function Get-LatestGostVersion {
    try {
        Write-ColorOutput $Strings.FetchingVersion "Cyan"
        Write-DebugLog "Get-LatestGostVersion: Starting"
        $apiUrl = "https://api.github.com/repos/$GITHUB_REPO/releases/latest"
        Write-DebugLog "API URL: $apiUrl"
        $response = Invoke-RestMethod -Uri $apiUrl -Headers @{"Accept"="application/vnd.github.v3+json"}
        Write-DebugLog "Response type: $($response.GetType().Name)"
        Write-DebugLog "Response properties: $($response.PSObject.Properties.Name -join ', ')"

        # Ensure tag_name exists (handle case sensitivity)
        if ($response.tag_name) {
            $versionTag = $response.tag_name
            Write-DebugLog "Found tag_name: $versionTag"
        } elseif ($response.TAG_NAME) {
            $versionTag = $response.TAG_NAME
            Write-DebugLog "Found TAG_NAME: $versionTag"
        } elseif ($response.name) {
            $versionTag = $response.name
            Write-DebugLog "Found name: $versionTag"
        } else {
            Write-ColorOutput "Failed to extract version from response" "Red"
            Write-DebugLog "ERROR: No version tag found in response"
            return $null
        }

        Write-ColorOutput "$($Strings.LatestVersion)$versionTag" "Green"
        return $response
    } catch {
        Write-ColorOutput "Failed to get version info: $_" "Red"
        Write-DebugLog "ERROR: $_"
        return $null
    }
}

# Download GOST
function Download-Gost {
    param([object]$Version, [string]$Architecture)

    Write-DebugLog "Download-Gost: Version type = $($Version.GetType().Name)"
    Write-DebugLog "Download-Gost: Version is null? = $($Version -eq $null)"

    if ($Version -eq $null) {
        Write-ColorOutput "Error: Version object is null" "Red"
        Write-DebugLog "ERROR: Version parameter is null"
        return $null
    }

    Write-DebugLog "Download-Gost: Version properties = $($Version.PSObject.Properties.Name -join ', ')"

    # Extract tag_name with fallback for different property names
    if ($Version.PSObject.Properties['tag_name']) {
        $tagName = $Version.tag_name
        Write-DebugLog "Found tag_name property: $tagName"
    } elseif ($Version.PSObject.Properties['TAG_NAME']) {
        $tagName = $Version.TAG_NAME
        Write-DebugLog "Found TAG_NAME property: $tagName"
    } elseif ($Version.PSObject.Properties['name']) {
        $tagName = $Version.name
        Write-DebugLog "Found name property: $tagName"
    } else {
        Write-ColorOutput "Error: Cannot find version tag in response object" "Red"
        Write-DebugLog "ERROR: No version tag found in Version object"
        return $null
    }

    # Direct download URL construction
    $versionTag = $tagName -replace '^v', ''
    $downloadUrl = "https://github.com/$GITHUB_REPO/releases/download/$tagName/gost_${versionTag}_windows_${Architecture}.zip"
    Write-ColorOutput "Download URL: $downloadUrl" "Gray"
    Write-DebugLog "Constructed URL: $downloadUrl"

    # Create download directory
    New-Item -Path $DOWNLOAD_DIR -ItemType Directory -Force | Out-Null
    $zipFile = "$DOWNLOAD_DIR\gost.zip"

    try {
        Write-ColorOutput "Downloading GOST $tagName..." "Cyan"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile -UseBasicParsing
        Write-ColorOutput "Download completed" "Green"
        return $zipFile
    } catch {
        Write-ColorOutput "Download failed: $_" "Red"

        # List all available versions
        Write-ColorOutput "`nAvailable Windows versions:" "Cyan"
        Write-Host "  386:   https://github.com/$GITHUB_REPO/releases/download/$tagName/gost_${versionTag}_windows_386.zip" "Gray"
        Write-Host "  amd64: https://github.com/$GITHUB_REPO/releases/download/$tagName/gost_${versionTag}_windows_amd64.zip" "Gray"
        Write-Host "  arm64: https://github.com/$GITHUB_REPO/releases/download/$tagName/gost_${versionTag}_windows_arm64.zip" "Gray"

        return $null
    }
}

# Extract and install binary
function Install-GostBinary {
    param([string]$ZipFile)

    try {
        Write-ColorOutput "Extracting files..." "Cyan"

        # Try to extract, handle Defender blocking
        try {
            Expand-Archive -Path $ZipFile -DestinationPath $DOWNLOAD_DIR -Force
        } catch {
            $errorMsg = $_.Exception.Message
            Write-DebugLog "Expand-Archive error: $errorMsg"

            # Check if it's a Defender block
            if ($errorMsg -match "virus" -or $errorMsg -match "potentially unwanted") {
                Write-ColorOutput "Detected: File blocked by Windows Defender" "Yellow"
                Write-ColorOutput "Attempting to add exclusion and retry..." "Cyan"

                # Add the download directory and zip file to Defender exclusions
                try {
                    Add-MpPreference -ExclusionPath $DOWNLOAD_DIR -ErrorAction SilentlyContinue
                    Add-MpPreference -ExclusionPath $ZipFile -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 1
                    Write-ColorOutput "Added to Defender exclusions, retrying extraction..." "Yellow"

                    # Retry extraction
                    Expand-Archive -Path $ZipFile -DestinationPath $DOWNLOAD_DIR -Force
                } catch {
                    Write-ColorOutput "Automatic exclusion failed. Manual action required:" "Red"
                    Write-ColorOutput "1. Open Windows Security" "Yellow"
                    Write-ColorOutput "2. Go to Virus & threat protection > Manage settings" "Yellow"
                    Write-ColorOutput "3. Scroll to Exclusions > Add or remove exclusions" "Yellow"
                    Write-ColorOutput "4. Add folder: $DOWNLOAD_DIR" "Yellow"
                    Write-ColorOutput "5. Then press Enter to retry" "Yellow"
                    Read-Host
                    Expand-Archive -Path $ZipFile -DestinationPath $DOWNLOAD_DIR -Force
                }
            } else {
                throw $_
            }
        }

        New-Item -Path $INSTALL_DIR -ItemType Directory -Force | Out-Null

        $exeSource = Get-ChildItem -Path $DOWNLOAD_DIR -Filter "gost.exe" -Recurse | Select-Object -First 1
        if ($exeSource) {
            Copy-Item -Path $exeSource.FullName -Destination "$INSTALL_DIR\gost.exe" -Force
            Write-ColorOutput "Installed to: $INSTALL_DIR\gost.exe" "Green"
            return $true
        } else {
            Write-ColorOutput "gost.exe not found" "Red"
            return $false
        }
    } catch {
        Write-ColorOutput "Installation failed: $_" "Red"
        Write-DebugLog "Install-GostBinary failed: $_"
        return $false
    }
}

# Create default config file (JSON format)
function New-GostConfig {
    $configContent = @{
        services = @(
            @{
                name = "socks5-proxy"
                addr = ":10800"
                handler = @{ type = "socks5" }
                listener = @{ type = "tcp" }
            }
        )
        api = @{ addr = "0.0.0.0:8090" }
    } | ConvertTo-Json -Depth 10

    try {
        Set-Content -Path $CONFIG_FILE -Value $configContent -Encoding UTF8
        Write-ColorOutput "Config file created: $CONFIG_FILE" "Green"
        return $true
    } catch {
        Write-ColorOutput "Failed to create config: $_" "Red"
        return $false
    }
}

# Install Windows service
function Install-GostService {
    param([string]$ExePath, [string]$ConfigPath)

    try {
        Write-ColorOutput "Installing Windows service..." "Cyan"
        $serviceName = $SERVICE_NAME

        $existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($existingService) {
            Write-ColorOutput "Removing existing service..." "Yellow"
            Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
            sc.exe delete $serviceName | Out-Null
            Start-Sleep -Seconds 2
        }

        $binPath = "`"$ExePath`" -C `"$ConfigPath`""
        $result = sc.exe create $serviceName binPath= "$binPath" start= auto DisplayName= "GOST Port Forwarding Service" 2>&1
        if ($LASTEXITCODE -eq 0) {
            sc.exe description $serviceName "GOST Port Forwarding Service - Managed by gost-ui" | Out-Null
            sc.exe failure $serviceName reset= 86400 actions= restart/5000/restart/10000/restart/20000 | Out-Null

            Write-ColorOutput "Service installed: $serviceName" "Green"
            Write-ColorOutput "Service commands:" "Cyan"
            Write-Host "  Start: net start $serviceName" -ForegroundColor Gray
            Write-Host "  Stop: net stop $serviceName" -ForegroundColor Gray
            return $true
        } else {
            Write-ColorOutput "Failed to create service: $result" "Red"
            return $false
        }
    } catch {
        Write-ColorOutput "Service installation failed: $_" "Red"
        return $false
    }
}

# Configure firewall rules
function Set-FirewallRule {
    param([int]$ApiPort = 8090)

    try {
        Write-ColorOutput "Configuring firewall..." "Cyan"
        Remove-NetFirewallRule -DisplayName "GOST API" -ErrorAction SilentlyContinue
        Remove-NetFirewallRule -DisplayName "GOST Service" -ErrorAction SilentlyContinue
        New-NetFirewallRule -DisplayName "GOST API" -Direction Inbound -LocalPort $ApiPort -Protocol TCP -Action Allow | Out-Null
        Write-ColorOutput "Firewall rule added: TCP port $ApiPort" "Green"
        return $true
    } catch {
        Write-ColorOutput "Failed to configure firewall: $_" "Yellow"
        return $false
    }
}

# Clean temp files
function Remove-TempFiles {
    if (Test-Path $DOWNLOAD_DIR) {
        Remove-Item -Path $DOWNLOAD_DIR -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Add to PATH
function Add-ToPath {
    param([string]$Path)

    try {
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($currentPath -notlike "*$Path*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$Path", "Machine")
            Write-ColorOutput "Added to system PATH: $Path" "Green"
        }
        return $true
    } catch {
        return $false
    }
}

# Remove from PATH
function Remove-FromPath {
    param([string]$Path)

    try {
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($currentPath -like "*$Path*") {
            $pathEntries = $currentPath -split ';'
            $newPath = ($pathEntries | Where-Object { $_.Trim() -ne $Path }) -join ';'
            [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
            Write-ColorOutput "Removed from system PATH: $Path" "Green"
        }
        return $true
    } catch {
        return $false
    }
}

# Full installation
function Install-Full {
    Clear-Host
    Write-ColorOutput "`n========================================" "Cyan"
    Write-ColorOutput "      Installing GOST" "Cyan"
    Write-ColorOutput "========================================`n" "Cyan"

    # Check and optionally disable Windows Defender
    $defenderWasDisabled = $false
    if (Test-DefenderStatus) {
        $defenderWasDisabled = Disable-DefenderTemp
    }

    try {
        Write-DebugLog "Install-Full: Starting installation process"
        $versionInfo = Get-LatestGostVersion
    Write-DebugLog "Install-Full: versionInfo type = $($versionInfo.GetType().Name)"
    if (-not $versionInfo) {
        Write-ColorOutput "`nPress any key to return..." "Yellow"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return $false
    }

    $architecture = Get-SystemArchitecture
    if (-not $architecture) {
        Write-ColorOutput "`nPress any key to return..." "Yellow"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return $false
    }

    $zipFile = Download-Gost -Version $versionInfo -Architecture $architecture
    if (-not $zipFile) {
        Write-ColorOutput "`nPress any key to return..." "Yellow"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return $false
    }

    if (-not (Install-GostBinary -ZipFile $zipFile)) {
        Write-ColorOutput "`nPress any key to return..." "Yellow"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return $false
    }

    New-GostConfig
    Set-FirewallRule -ApiPort 8090
    Add-ToPath -Path $INSTALL_DIR

    Write-ColorOutput "`nInstall as Windows service? (Y/N)" "Yellow"
    $installService = Read-Host

    if ($installService -eq "Y" -or $installService -eq "y") {
        if (Install-GostService -ExePath "$INSTALL_DIR\gost.exe" -ConfigPath $CONFIG_FILE) {
            Write-ColorOutput "`nStart service now? (Y/N)" "Yellow"
            $startService = Read-Host
            if ($startService -eq "Y" -or $startService -eq "y") {
                Start-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
                Write-ColorOutput "Service started" "Green"
            }
        }
    }

    Remove-TempFiles

    Write-ColorOutput "`n========================================" "Green"
    Write-ColorOutput "        Installation Complete!" "Green"
    Write-ColorOutput "========================================`n" "Green"
    Write-ColorOutput "Install dir: $INSTALL_DIR" "White"
    Write-ColorOutput "Config file: $CONFIG_FILE" "White"
    Write-ColorOutput "API address: http://localhost:8090" "White"

    } finally {
        # Always re-enable Defender if we disabled it
        if ($defenderWasDisabled) {
            Enable-Defender
        }
    }

    Write-ColorOutput "`nPress any key to return..." "Yellow"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    return $true
}

# Service only installation
function Install-ServiceOnly {
    Clear-Host
    Write-ColorOutput "`n========================================" "Cyan"
    Write-ColorOutput "      Installing Service Only" "Cyan"
    Write-ColorOutput "========================================`n" "Cyan"

    if (-not (Test-Path "$INSTALL_DIR\gost.exe")) {
        Write-ColorOutput "Error: $INSTALL_DIR\gost.exe not found" "Red"
        Write-ColorOutput "Please run Full Install first" "Yellow"
        Write-ColorOutput "`nPress any key to return..." "Yellow"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return $false
    }

    if (-not (Test-Path $CONFIG_FILE)) {
        Write-ColorOutput "Config not found. Create default? (Y/N)" "Yellow"
        $createConfig = Read-Host
        if ($createConfig -eq "Y" -or $createConfig -eq "y") {
            New-GostConfig
        } else {
            Write-ColorOutput "`nPress any key to return..." "Yellow"
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return $false
        }
    }

    Set-FirewallRule -ApiPort 8090
    Add-ToPath -Path $INSTALL_DIR

    if (Install-GostService -ExePath "$INSTALL_DIR\gost.exe" -ConfigPath $CONFIG_FILE) {
        Write-ColorOutput "`nStart service now? (Y/N)" "Yellow"
        $startService = Read-Host
        if ($startService -eq "Y" -or $startService -eq "y") {
            Start-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
            Write-ColorOutput "Service started" "Green"
        }
    }

    Write-ColorOutput "`nPress any key to return..." "Yellow"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    return $true
}

# Uninstall GOST
function Uninstall-Gost {
    Clear-Host
    Write-ColorOutput "`n========================================" "Yellow"
    Write-ColorOutput "      Uninstalling GOST" "Yellow"
    Write-ColorOutput "========================================`n" "Yellow"

    Write-ColorOutput "Warning: This will remove GOST and configurations" "Red"
    Write-ColorOutput "`nContinue? (Y/N)" "Yellow"
    $confirm = Read-Host

    if ($confirm -ne "Y" -and $confirm -ne "y") {
        Write-ColorOutput "Cancelled" "Gray"
        Write-ColorOutput "`nPress any key to return..." "Yellow"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return $false
    }

    $existingService = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
    if ($existingService) {
        Write-ColorOutput "Stopping service..." "Cyan"
        Stop-Service -Name $SERVICE_NAME -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        sc.exe delete $SERVICE_NAME | Out-Null
        Write-ColorOutput "Service removed" "Green"
    }

    Write-ColorOutput "Removing firewall rules..." "Cyan"
    Remove-NetFirewallRule -DisplayName "GOST API" -ErrorAction SilentlyContinue
    Remove-NetFirewallRule -DisplayName "GOST Service" -ErrorAction SilentlyContinue
    Write-ColorOutput "Firewall rules removed" "Green"

    if (Test-Path $INSTALL_DIR) {
        Write-ColorOutput "Removing install directory: $INSTALL_DIR" "Cyan"
        Write-ColorOutput "`nKeep config file? (Y/N)" "Yellow"
        $keepConfig = Read-Host

        if ($keepConfig -eq "Y" -or $keepConfig -eq "y") {
            $backupPath = "$env:USERPROFILE\Desktop\gost-config-backup.json"
            Copy-Item -Path $CONFIG_FILE -Destination $backupPath -Force -ErrorAction SilentlyContinue
            if (Test-Path $backupPath) {
                Write-ColorOutput "Config backed up to: $backupPath" "Green"
            }
        }
        Remove-Item -Path $INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
        Write-ColorOutput "Install directory removed" "Green"
    }

    Remove-FromPath -Path $INSTALL_DIR

    Write-ColorOutput "`n========================================" "Green"
    Write-ColorOutput "        Uninstall Complete!" "Green"
    Write-ColorOutput "========================================`n" "Green"

    Write-ColorOutput "`nPress any key to return..." "Yellow"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    return $true
}

# Check for updates
function Check-Update {
    Clear-Host
    Write-ColorOutput "`n========================================" "Cyan"
    Write-ColorOutput "      Check Update" "Cyan"
    Write-ColorOutput "========================================`n" "Cyan"

    $versionInfo = Get-LatestGostVersion
    if (-not $versionInfo) {
        Write-ColorOutput "`nPress any key to return..." "Yellow"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    $currentVersion = $null
    if (Test-Path "$INSTALL_DIR\gost.exe") {
        try {
            $versionOutput = & "$INSTALL_DIR\gost.exe" -V 2>&1
            # GOST version output format: "gost x.y.z (build info)" or similar
            # Try multiple patterns for better compatibility
            if ($versionOutput -match "gost\s+([\d\.]+)") {
                $currentVersion = $matches[1]
            } elseif ($versionOutput -match "v([\d\.]+)") {
                $currentVersion = $matches[1]
            } elseif ($versionOutput -match "version[:\s]+([\d\.]+)") {
                $currentVersion = $matches[1]
            }
            Write-ColorOutput "Current version: $currentVersion" "Cyan"
            Write-ColorOutput "Debug - version output: $versionOutput" "DarkGray"
        } catch {
            Write-ColorOutput "Cannot detect current version" "Yellow"
        }
    } else {
        Write-ColorOutput "GOST not installed" "Yellow"
        Write-ColorOutput "`nPress any key to return..." "Yellow"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    $latestVersion = $versionInfo.tag_name.TrimStart('v')

    if ($currentVersion -eq $latestVersion) {
        Write-ColorOutput "`nAlready up to date!" "Green"
    } else {
        Write-ColorOutput "`nNew version available!" "Yellow"
        Write-ColorOutput "Current: $currentVersion -> Latest: $latestVersion" "Cyan"
        Write-ColorOutput "`nUpdate now? (Y/N)" "Yellow"
        $updateConfirm = Read-Host

        if ($updateConfirm -eq "Y" -or $updateConfirm -eq "y") {
            Write-ColorOutput "`nUpdating..." "Cyan"

            $existingService = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
            if ($existingService) {
                Write-ColorOutput "Stopping service..." "Cyan"
                Stop-Service -Name $SERVICE_NAME -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 1
            }

            $architecture = Get-SystemArchitecture
            if (-not $architecture) {
                Write-ColorOutput "`nPress any key to return..." "Yellow"
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                return
            }

            $zipFile = Download-Gost -Version $versionInfo -Architecture $architecture
            if (-not $zipFile) {
                Write-ColorOutput "`nPress any key to return..." "Yellow"
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                return
            }

            $backupDir = "$INSTALL_DIR\backup_$currentVersion"
            if (Test-Path "$INSTALL_DIR\gost.exe") {
                Write-ColorOutput "Backing up to: $backupDir" "Cyan"
                New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
                Copy-Item -Path "$INSTALL_DIR\gost.exe" -Destination "$backupDir\gost.exe" -Force
            }

            Write-ColorOutput "Installing new version..." "Cyan"
            try {
                Expand-Archive -Path $zipFile -DestinationPath $DOWNLOAD_DIR -Force
            } catch {
                $errorMsg = $_.Exception.Message
                if ($errorMsg -match "virus" -or $errorMsg -match "potentially unwanted") {
                    Write-ColorOutput "File blocked by Defender, adding exclusion..." "Yellow"
                    Add-MpPreference -ExclusionPath $DOWNLOAD_DIR -ErrorAction SilentlyContinue
                    Add-MpPreference -ExclusionPath $zipFile -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 1
                    Expand-Archive -Path $zipFile -DestinationPath $DOWNLOAD_DIR -Force
                } else {
                    throw $_
                }
            }
            $exeSource = Get-ChildItem -Path $DOWNLOAD_DIR -Filter "gost.exe" -Recurse | Select-Object -First 1
            if ($exeSource) {
                Copy-Item -Path $exeSource.FullName -Destination "$INSTALL_DIR\gost.exe" -Force
                Write-ColorOutput "Update complete!" "Green"
            }

            Remove-TempFiles

            if ($existingService) {
                Write-ColorOutput "Restarting service..." "Cyan"
                Start-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
                Write-ColorOutput "Service restarted" "Green"
            }

            Write-ColorOutput "`nNew version: $latestVersion" "White"
            Write-ColorOutput "Backup location: $backupDir" "Gray"
        }
    }

    Write-ColorOutput "`nPress any key to return..." "Yellow"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# View log file
function View-Log {
    Clear-Host
    Write-ColorOutput "`n========================================" "Cyan"
    Write-ColorOutput "      View Log File" "Cyan"
    Write-ColorOutput "========================================`n" "Cyan"

    # Find all log files
    $logDir = [System.IO.Path]::GetTempPath()
    $logFiles = Get-ChildItem -Path $logDir -Filter "gost-install_*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending

    if (-not $logFiles -or $logFiles.Count -eq 0) {
        Write-ColorOutput "No log files found" "Yellow"
        Write-ColorOutput "Current log file: $LOG_FILE" "Gray"
    } else {
        Write-ColorOutput "Found $($logFiles.Count) log file(s):`n" "Cyan"
        for ($i = 0; $i -lt $logFiles.Count; $i++) {
            $file = $logFiles[$i]
            $size = [math]::Round($file.Length / 1KB, 1)
            Write-Host "  [$($i+1)] " -NoNewline -ForegroundColor Cyan
            Write-Host "$($file.Name) " -NoNewline
            Write-Host "($size KB, $($file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')))" -ForegroundColor Gray
        }

        Write-Host "`n[0] Open current log file in notepad"
        Write-Host "[L] List all logs in full text"
        Write-Host ""

        $selection = Read-Host "Select log file to view (1-$($logFiles.Count), 0 for notepad, L to list, or Enter to return)"

        if ($selection -eq "0") {
            # Open current log in notepad
            if (Test-Path $LOG_FILE) {
                notepad.exe $LOG_FILE
            } else {
                Write-ColorOutput "Current log file not found yet" "Yellow"
            }
        } elseif ($selection -eq "L" -or $selection -eq "l") {
            # Show most recent log content
            $latestLog = $logFiles[0].FullName
            Write-ColorOutput "`n========== Content of $($logFiles[0].Name) ==========`n" "Cyan"
            Get-Content -Path $latestLog -Tail 50
            Write-ColorOutput "`n========== End of log (showing last 50 lines) ==========" "Cyan"
        } elseif ($selection -match "^\d+$" -and [int]$selection -ge 1 -and [int]$selection -le $logFiles.Count) {
            # Open selected log in notepad
            $selectedIndex = [int]$selection - 1
            $selectedFile = $logFiles[$selectedIndex].FullName
            Write-ColorOutput "Opening: $($logFiles[$selectedIndex].Name)" "Cyan"
            notepad.exe $selectedFile
        }
    }

    if ($selection -ne "0" -and $selection -notmatch "^\d+$") {
        Write-ColorOutput "`nPress any key to return..." "Yellow"
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

# =============================================================================
# Main
# =============================================================================

# Initialize logging
Initialize-Log

if ($args.Count -gt 0) {
    $Action = $args[0].ToLower()
    switch ($Action) {
        "install" { Install-Full }
        "uninstall" { Uninstall-Gost }
        "update" { Check-Update }
        default {
            Write-ColorOutput "Unknown action: $Action" "Red"
            Write-Host "`nUsage:" -ForegroundColor Cyan
            Write-Host "  install.ps1 install" -ForegroundColor Gray
            Write-Host "  install.ps1 uninstall" -ForegroundColor Gray
            Write-Host "  install.ps1 update" -ForegroundColor Gray
        }
    }
    return
}

do {
    $choice = Show-MainMenu

    switch ($choice) {
        "1" {
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
            View-Log
        }
        "5" {
            Write-ColorOutput "`nGoodbye!" "Green"
            return
        }
        default {
            Write-ColorOutput "`nInvalid option" "Red"
            Start-Sleep -Seconds 1
        }
    }
} while ($true)
