# =============================================================================
# Update External Dependencies Script
# Purpose: Automatically update GOST and gost-ui in external/ directory
# Usage: PowerShell -ExecutionPolicy Bypass -File update-external.ps1
# =============================================================================

#Requires -RunAsAdministrator

# Configuration
$GITHUB_REPO_GOST = "go-gost/gost"
$GITHUB_REPO_GOST_UI = "go-gost/gost-ui"
$EXTERNAL_DIR = Join-Path $PSScriptRoot "external"
$GOST_DIR = Join-Path $EXTERNAL_DIR "gost"
$GOST_SOURCE_DIR = Join-Path $GOST_DIR "gost-master"
$GOST_UI_DIR = Join-Path $EXTERNAL_DIR "gost-ui"
$VERSIONS_FILE = Join-Path $EXTERNAL_DIR "VERSIONS.txt"
$DOWNLOAD_DIR = Join-Path $env:TEMP "gost_update"

# Detect system language
$systemLang = (Get-Culture).TwoLetterISOLanguageName
$IsChineseSystem = ($systemLang -eq "zh") -or ($systemLang -eq "zh-CN") -or ($systemLang -eq "zh-TW")

# Localization
$Strings = @{
    Title = if ($IsChineseSystem) { "更新外部依赖" } else { "Update External Dependencies" }
    FetchingVersion = if ($IsChineseSystem) { "正在获取最新版本信息..." } else { "Fetching latest version info..." }
    CurrentVersion = if ($IsChineseSystem) { "当前版本: {0}" } else { "Current version: {0}" }
    LatestVersion = if ($IsChineseSystem) { "最新版本: {0}" } else { "Latest version: {0}" }
    AlreadyUpToDate = if ($IsChineseSystem) { "已是最新版本" } else { "Already up to date" }
    NewVersionAvailable = if ($IsChineseSystem) { "发现新版本!" } else { "New version available!" }
    Downloading = if ($IsChineseSystem) { "正在下载 {0}..." } else { "Downloading {0}..." }
    DownloadComplete = if ($IsChineseSystem) { "下载完成" } else { "Download complete" }
    DownloadFailed = if ($IsChineseSystem) { "下载失败: {0}" } else { "Download failed: {0}" }
    UpdatingSource = if ($IsChineseSystem) { "正在更新源码..." } else { "Updating source code..." }
    SourceUpdated = if ($IsChineseSystem) { "源码已更新" } else { "Source code updated" }
    UpdateVersionsFile = if ($IsChineseSystem) { "正在更新版本文件..." } else { "Updating versions file..." }
    VersionsFileUpdated = if ($IsChineseSystem) { "版本文件已更新: {0}" } else { "Versions file updated: {0}" }
    Error = if ($IsChineseSystem) { "错误" } else { "Error" }
    Complete = if ($IsChineseSystem) { "更新完成!" } else { "Update complete!" }
    PressKey = if ($IsChineseSystem) { "`n按任意键退出..." } else { "`nPress any key to exit..." }
}

# Color output
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

# Get latest GOST release version
function Get-LatestGostVersion {
    try {
        Write-ColorOutput $Strings.FetchingVersion "Cyan"
        $apiUrl = "https://api.github.com/repos/$GITHUB_REPO_GOST/releases/latest"
        $response = Invoke-RestMethod -Uri $apiUrl -Headers @{"Accept"="application/vnd.github.v3+json"}
        return $response
    } catch {
        Write-ColorOutput "$($Strings.Error): $_" "Red"
        return $null
    }
}

# Get current version from VERSIONS.txt
function Get-CurrentVersion {
    if (Test-Path $VERSIONS_FILE) {
        $content = Get-Content $VERSIONS_FILE -Raw
        if ($content -match 'GOST\r?\n\s*-\s*版本:\s*v([\d.]+)') {
            return $matches[1]
        }
    }
    return $null
}

# Download GOST release binaries
function Download-GostBinaries {
    param([string]$Version, [string]$Tag)

    Write-ColorOutput "`n========================================" "Cyan"
    Write-ColorOutput "      Downloading GOST Binaries" "Cyan"
    Write-ColorOutput "========================================`n" "Cyan"

    $versionNum = $Tag -replace '^v', ''

    # Platforms and architectures to download
    $platforms = @(
        @{OS="linux"; Arch="amd64"; Ext="tar.gz"}
        @{OS="linux"; Arch="386"; Ext="tar.gz"}
        @{OS="linux"; Arch="arm64"; Ext="tar.gz"}
        @{OS="windows"; Arch="amd64"; Ext="zip"}
        @{OS="windows"; Arch="386"; Ext="zip"}
        @{OS="windows"; Arch="arm64"; Ext="zip"}
    )

    New-Item -Path $DOWNLOAD_DIR -ItemType Directory -Force | Out-Null

    foreach ($platform in $platforms) {
        $filename = "gost_${versionNum}_${platform.OS}_${platform.Arch}.$($platform.Ext)"
        $downloadUrl = "https://github.com/$GITHUB_REPO_GOST/releases/download/$Tag/$filename"
        $outputFile = Join-Path $DOWNLOAD_DIR $filename

        Write-ColorOutput "$($Strings.Downloading) -f $filename" "Yellow"
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $outputFile -UseBasicParsing
            Write-ColorOutput "  $OK" "Green"
        } catch {
            Write-ColorOutput "  $($Strings.DownloadFailed) -f $_" "Red"
            return $false
        }
    }

    # Copy to external directory
    Write-ColorOutput "`nCopying files to external directory..." "Cyan"
    Get-ChildItem -Path $DOWNLOAD_DIR -Filter "*.tar.gz" | Copy-Item -Destination $EXTERNAL_DIR -Force
    Get-ChildItem -Path $DOWNLOAD_DIR -Filter "*.zip" | Copy-Item -Destination $EXTERNAL_DIR -Force

    # Clean up old version files
    Write-ColorOutput "Cleaning up old version files..." "Yellow"
    Get-ChildItem -Path $EXTERNAL_DIR -Filter "gost_*.tar.gz" | Where-Object { $_.Name -notmatch $versionNum } | Remove-Item -Force
    Get-ChildItem -Path $EXTERNAL_DIR -Filter "gost_*.zip" | Where-Object { $_.Name -notmatch $versionNum } | Remove-Item -Force

    # Clean temp directory
    Remove-Item -Path $DOWNLOAD_DIR -Recurse -Force -ErrorAction SilentlyContinue

    Write-ColorOutput $Strings.DownloadComplete "Green"
    return $true
}

# Update GOST source code
function Update-GostSource {
    param([string]$Tag)

    Write-ColorOutput "`n========================================" "Cyan"
    Write-ColorOutput "      Updating GOST Source" "Cyan"
    Write-ColorOutput "========================================`n" "Cyan"

    if (Test-Path $GOST_SOURCE_DIR) {
        # Update existing git repository
        Write-ColorOutput "Updating existing git repository..." "Yellow"
        Push-Location $GOST_SOURCE_DIR
        try {
            git fetch origin
            git checkout $Tag
            git pull origin $Tag
            Pop-Location
            Write-ColorOutput $Strings.SourceUpdated "Green"
            return $true
        } catch {
            Pop-Location
            Write-ColorOutput "$($Strings.Error): $_" "Red"
            return $false
        }
    } else {
        # Clone new repository
        Write-ColorOutput "Cloning GOST repository..." "Yellow"
        New-Item -Path $GOST_DIR -ItemType Directory -Force | Out-Null
        try {
            git clone --depth 1 --branch $Tag "https://github.com/$GITHUB_REPO_GOST.git" $GOST_SOURCE_DIR
            Write-ColorOutput $Strings.SourceUpdated "Green"
            return $true
        } catch {
            Write-ColorOutput "$($Strings.Error): $_" "Red"
            return $false
        }
    }
}

# Update gost-ui source code
function Update-GostUiSource {
    Write-ColorOutput "`n========================================" "Cyan"
    Write-ColorOutput "      Updating gost-ui Source" "Cyan"
    Write-ColorOutput "========================================`n" "Cyan"

    if (Test-Path (Join-Path $GOST_UI_DIR ".git")) {
        # Update existing git repository
        Write-ColorOutput "Updating existing git repository..." "Yellow"
        Push-Location $GOST_UI_DIR
        try {
            git fetch origin
            $latestCommit = git rev-parse origin/master
            git checkout master
            git pull origin master
            Pop-Location
            Write-ColorOutput "$($Strings.SourceUpdated) (commit: $latestCommit.Substring(0,7))" "Green"
            return $latestCommit
        } catch {
            Pop-Location
            Write-ColorOutput "$($Strings.Error): $_" "Red"
            return $null
        }
    } else {
        # Clone new repository
        Write-ColorOutput "Cloning gost-ui repository..." "Yellow"
        try {
            # Backup existing directory if it's not a git repo
            if (Test-Path $GOST_UI_DIR) {
                $backupDir = "$GOST_UI_DIR.bak"
                Write-ColorOutput "Backing up existing directory to: $backupDir" "Yellow"
                Move-Item -Path $GOST_UI_DIR -Destination $backupDir -Force
            }

            git clone --depth 1 --branch master "https://github.com/$GITHUB_REPO_GOST_UI.git" $GOST_UI_DIR
            $latestCommit = git -C $GOST_UI_DIR rev-parse HEAD
            Write-ColorOutput "$($Strings.SourceUpdated) (commit: $latestCommit.Substring(0,7))" "Green"
            return $latestCommit
        } catch {
            Write-ColorOutput "$($Strings.Error): $_" "Red"
            return $null
        }
    }
}

# Update VERSIONS.txt file
function Update-VersionsFile {
    param([string]$GostVersion, [string]$GostUiCommit)

    Write-ColorOutput "`n========================================" "Cyan"
    Write-ColorOutput "      Updating VERSIONS.txt" "Cyan"
    Write-ColorOutput "========================================`n" "Cyan"

    $date = Get-Date -Format "yyyy-MM-dd"
    $content = @"
# External Dependencies
# 下载/更新时间: $date

## GOST
- 版本: v$GostVersion
- 仓库: https://github.com/go-gost/gost
- 源码目录: gost/gost-master/
- Release 文件:
  * gost_${GostVersion}_linux_386.tar.gz
  * gost_${GostVersion}_linux_amd64.tar.gz
  * gost_${GostVersion}_linux_arm64.tar.gz
  * gost_${GostVersion}_windows_386.zip
  * gost_${GostVersion}_windows_amd64.zip
  * gost_${GostVersion}_windows_arm64.zip

## gost-ui
- 版本: master (commit: ${GostUiCommit})
- 仓库: https://github.com/go-gost/gost-ui
- 源码目录: gost-ui/
"@

    Set-Content -Path $VERSIONS_FILE -Value $content -Encoding UTF8
    Write-ColorOutput "$($Strings.VersionsFileUpdated) -f $VERSIONS_FILE" "Green"
}

# =============================================================================
# Main
# =============================================================================

Clear-Host
Write-ColorOutput "`n========================================" "Cyan"
Write-ColorOutput "      $($Strings.Title)" "Cyan"
Write-ColorOutput "========================================`n" "Cyan"

# Check if git is available
try {
    git --version | Out-Null
} catch {
    Write-ColorOutput "Error: Git not found. Please install Git first." "Red"
    Write-ColorOutput "`nDownload Git: https://git-scm.com/downloads" "Yellow"
    pause
    exit 1
}

# Get version info
$versionInfo = Get-LatestGostVersion
if (-not $versionInfo) {
    Write-ColorOutput $Strings.PressKey "Yellow"
    pause
    exit 1
}

$latestTag = $versionInfo.tag_name
$latestVersion = $latestTag -replace '^v', ''

# Show version comparison
$currentVersion = Get-CurrentVersion
Write-ColorOutput "$($Strings.CurrentVersion) -f $(if ($currentVersion) { "v$currentVersion" } else { 'None' })" "Cyan"
Write-ColorOutput "$($Strings.LatestVersion) -f $latestTag" "Green"

if ($currentVersion -eq $latestVersion) {
    Write-ColorOutput "`n$($Strings.AlreadyUpToDate)" "Yellow"

    $updateAnyway = Read-Host "`nUpdate anyway? (Y/N)"
    if ($updateAnyway -ne "Y" -and $updateAnyway -ne "y") {
        Write-ColorOutput $Strings.PressKey "Yellow"
        pause
        exit 0
    }
} else {
    Write-ColorOutput "`n$($Strings.NewVersionAvailable)" "Green"
    $confirm = Read-Host "`nContinue with update? (Y/N)"
    if ($confirm -ne "Y" -and $confirm -ne "y") {
        Write-ColorOutput $Strings.PressKey "Yellow"
        pause
        exit 0
    }
}

# Update GOST binaries
if (-not (Download-GostBinaries -Version $latestVersion -Tag $latestTag)) {
    Write-ColorOutput $Strings.PressKey "Yellow"
    pause
    exit 1
}

# Update GOST source
Update-GostSource -Tag $latestTag

# Update gost-ui source
$gostUiCommit = Update-GostUiSource

# Update VERSIONS.txt
Update-VersionsFile -GostVersion $latestVersion -GostUiCommit $gostUiCommit

Write-ColorOutput "`n========================================" "Green"
Write-ColorOutput "      $($Strings.Complete)" "Green"
Write-ColorOutput "========================================`n" "Green"

Write-ColorOutput $Strings.PressKey "Yellow"
pause
