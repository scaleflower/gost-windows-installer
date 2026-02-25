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
    Write-ColorOutput "      GOST Windows Installer" "Cyan"
    Write-ColorOutput "========================================`n" "Cyan"

    Write-ColorOutput "Select an option:" "Yellow"
    Write-Host "  1. Install GOST"
    Write-Host "  2. Uninstall GOST"
    Write-Host "  3. Check Update"
    Write-Host "  4. View Log"
    Write-Host "  5. Exit"
    Write-Host ""

    $choice = Read-Host "Enter option (1-5)"
    return $choice
}

# Show install menu
function Show-InstallMenu {
    Clear-Host
    Write-ColorOutput "`n========================================" "Cyan"
    Write-ColorOutput "        Installation Options" "Cyan"
    Write-ColorOutput "========================================`n" "Cyan"

    Write-ColorOutput "Select installation type:" "Yellow"
    Write-Host "  1. Full Install (Download + Service)"
    Write-Host "  2. Service Only (Use existing files)"
    Write-Host "  3. Back to Main Menu"
    Write-Host ""

    $choice = Read-Host "Enter option (1-3)"
    return $choice
}

# Detect system architecture
function Get-SystemArchitecture {
    $processorArch = $env:PROCESSOR_ARCHITECTURE
    $archW64 = $env:PROCESSOR_ARCHITEW6432

    Write-ColorOutput "Detecting system..." "Cyan"
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
        Write-ColorOutput "Fetching latest GOST version..." "Cyan"
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

        Write-ColorOutput "Latest version: $versionTag" "Green"
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
        Expand-Archive -Path $ZipFile -DestinationPath $DOWNLOAD_DIR -Force

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
            Expand-Archive -Path $zipFile -DestinationPath $DOWNLOAD_DIR -Force
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
