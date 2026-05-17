# =============================================================================
# Update External Dependencies Script
# Purpose: Automatically update GOST and gost-ui in external/ directory
# Usage: PowerShell -ExecutionPolicy Bypass -File update-external-en.ps1
#
# GitHub Token (optional, for higher rate limit):
#   $env:GITHUB_TOKEN = "your_token_here"
#   Or create a .github_token file in the script directory
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

# Get GitHub token from environment variable or file
$githubToken = $env:GITHUB_TOKEN
if (-not $githubToken) {
    $tokenFile = Join-Path $PSScriptRoot ".github_token"
    if (Test-Path $tokenFile) {
        $githubToken = Get-Content $tokenFile -Raw
        $githubToken = $githubToken.Trim()
    }
}

# Color output
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

# Get latest GOST release version
function Get-LatestGostVersion {
    try {
        Write-ColorOutput "Fetching latest version info..." "Cyan"

        # Prepare headers with optional token
        $headers = @{"Accept"="application/vnd.github.v3+json"}
        if ($script:githubToken) {
            $headers["Authorization"] = "token $($script:githubToken)"
            Write-ColorOutput "Using GitHub token for authentication" "Gray"
        } else {
            Write-ColorOutput "No GitHub token found (rate limit: 60/hour)" "Yellow"
            Write-ColorOutput "Set `$env:GITHUB_TOKEN or create .github_token file for higher limit" "Gray"
        }

        # Method 1: Try GitHub API first
        try {
            $apiUrl = "https://api.github.com/repos/$GITHUB_REPO_GOST/releases/latest"
            $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers
            return $response
        } catch {
            # Method 2: Parse releases page HTML if API fails (e.g., rate limit)
            Write-ColorOutput "API rate limited, using alternative method..." "Yellow"
            $releasesUrl = "https://github.com/$GITHUB_REPO_GOST/releases"
            $html = Invoke-WebRequest -Uri $releasesUrl -UseBasicParsing

            # Extract tag name from HTML (look for /go-gost/gost/releases/tag/vX.X.X pattern)
            if ($html.Content -match '/go-gost/gost/releases/tag/(v[0-9]+\.[0-9]+\.[0-9]+)') {
                $tag = $matches[1].Trim()
                # Create a simple object with tag_name property
                return @{tag_name = $tag}
            } else {
                Write-ColorOutput "Failed to parse version from releases page" "Red"
                return $null
            }
        }
    } catch {
        Write-ColorOutput "Error: $_" "Red"
        return $null
    }
}

# Get current version from VERSIONS.txt
function Get-CurrentVersion {
    if (Test-Path $VERSIONS_FILE) {
        $content = Get-Content $VERSIONS_FILE -Raw
        if ($content -match 'GOST\r?\n\s*-\s*version:\s*v([\d.]+)') {
            return $matches[1]
        } elseif ($content -match 'GOST\r?\n\s*-\s*[Vv]ersion:\s*v([\d.]+)') {
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
        $filename = "gost_${versionNum}_$($platform.OS)_$($platform.Arch).$($platform.Ext)"
        $downloadUrl = "https://github.com/$GITHUB_REPO_GOST/releases/download/$Tag/$filename"
        $outputFile = Join-Path $DOWNLOAD_DIR $filename

        Write-ColorOutput "Downloading $filename..." "Yellow"
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $outputFile -UseBasicParsing
            Write-ColorOutput "  OK" "Green"
        } catch {
            Write-ColorOutput "  Failed: $_" "Red"
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

    Write-ColorOutput "Download complete" "Green"
    return $true
}

# Update GOST source code
function Update-GostSource {
    param([string]$Tag)

    Write-ColorOutput "`n========================================" "Cyan"
    Write-ColorOutput "      Updating GOST Source" "Cyan"
    Write-ColorOutput "========================================`n" "Cyan"

    if (Test-Path $GOST_SOURCE_DIR) {
        # Check if it's a git repository
        $gitDir = Join-Path $GOST_SOURCE_DIR ".git"
        if (Test-Path $gitDir) {
            # Update existing git repository
            Write-ColorOutput "Updating existing git repository..." "Yellow"
            Push-Location $GOST_SOURCE_DIR
            try {
                git fetch origin
                git checkout $Tag 2>$null
                git pull origin $Tag 2>$null
                Pop-Location
                Write-ColorOutput "Source code updated" "Green"
                return $true
            } catch {
                Pop-Location
                Write-ColorOutput "Error: $_" "Red"
                return $false
            }
        } else {
            # Not a git repo, delete and clone
            Write-ColorOutput "Existing directory found (not git), re-cloning..." "Yellow"
            Remove-Item -Path $GOST_SOURCE_DIR -Recurse -Force -ErrorAction SilentlyContinue
            New-Item -Path $GOST_DIR -ItemType Directory -Force | Out-Null
            try {
                git clone --depth 1 --branch $Tag "https://github.com/$GITHUB_REPO_GOST.git" $GOST_SOURCE_DIR
                Write-ColorOutput "Source code updated" "Green"
                return $true
            } catch {
                Write-ColorOutput "Error: $_" "Red"
                return $false
            }
        }
    } else {
        # Clone new repository
        Write-ColorOutput "Cloning GOST repository..." "Yellow"
        New-Item -Path $GOST_DIR -ItemType Directory -Force | Out-Null
        try {
            git clone --depth 1 --branch $Tag "https://github.com/$GITHUB_REPO_GOST.git" $GOST_SOURCE_DIR
            Write-ColorOutput "Source code updated" "Green"
            return $true
        } catch {
            Write-ColorOutput "Error: $_" "Red"
            return $false
        }
    }
}

# Update gost-ui source code
function Update-GostUiSource {
    Write-ColorOutput "`n========================================" "Cyan"
    Write-ColorOutput "      Updating gost-ui Source" "Cyan"
    Write-ColorOutput "========================================`n" "Cyan"

    $gitDir = Join-Path $GOST_UI_DIR ".git"

    if (Test-Path $gitDir) {
        # Update existing git repository
        Write-ColorOutput "Updating existing git repository..." "Yellow"
        Push-Location $GOST_UI_DIR
        try {
            git fetch origin
            $latestCommit = git rev-parse origin/master
            git checkout master 2>$null
            git pull origin master 2>$null
            Pop-Location
            Write-ColorOutput "Source code updated (commit: $($latestCommit.Substring(0,7)))" "Green"
            return $latestCommit
        } catch {
            Pop-Location
            Write-ColorOutput "Error: $_" "Red"
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
                Remove-Item -Path $backupDir -Recurse -Force -ErrorAction SilentlyContinue
                Move-Item -Path $GOST_UI_DIR -Destination $backupDir -Force
            }

            git clone --depth 1 --branch master "https://github.com/$GITHUB_REPO_GOST_UI.git" $GOST_UI_DIR
            $latestCommit = git -C $GOST_UI_DIR rev-parse HEAD
            Write-ColorOutput "Source code updated (commit: $($latestCommit.Substring(0,7)))" "Green"
            return $latestCommit
        } catch {
            Write-ColorOutput "Error: $_" "Red"
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
# Updated: $date

## GOST
- Version: v$GostVersion
- Repository: https://github.com/go-gost/gost
- Source directory: gost/gost-master/
- Release files:
  * gost_${GostVersion}_linux_386.tar.gz
  * gost_${GostVersion}_linux_amd64.tar.gz
  * gost_${GostVersion}_linux_arm64.tar.gz
  * gost_${GostVersion}_windows_386.zip
  * gost_${GostVersion}_windows_amd64.zip
  * gost_${GostVersion}_windows_arm64.zip

## gost-ui
- Version: master (commit: ${GostUiCommit})
- Repository: https://github.com/go-gost/gost-ui
- Source directory: gost-ui/
"@

    Set-Content -Path $VERSIONS_FILE -Value $content -Encoding UTF8
    Write-ColorOutput "Versions file updated: $VERSIONS_FILE" "Green"
}

# =============================================================================
# Main
# =============================================================================

Clear-Host
Write-ColorOutput "`n========================================" "Cyan"
Write-ColorOutput "      Update External Dependencies" "Cyan"
Write-ColorOutput "========================================`n" "Cyan"

# Check if git is available
try {
    $null = git --version 2>&1
} catch {
    Write-ColorOutput "Error: Git not found. Please install Git first." "Red"
    Write-ColorOutput "`nDownload Git: https://git-scm.com/downloads" "Yellow"
    pause
    exit 1
}

# Get version info
$versionInfo = Get-LatestGostVersion
if (-not $versionInfo) {
    Write-ColorOutput "`nPress any key to exit..." "Yellow"
    pause
    exit 1
}

$latestTag = $versionInfo.tag_name
$latestVersion = $latestTag -replace '^v', ''

# Show version comparison
$currentVersion = Get-CurrentVersion
Write-ColorOutput "Current version: $(if ($currentVersion) { "v$currentVersion" } else { 'None' })" "Cyan"
Write-ColorOutput "Latest version:  $latestTag" "Green"

if ($currentVersion -eq $latestVersion) {
    Write-ColorOutput "`nAlready up to date" "Yellow"

    $updateAnyway = Read-Host "`nUpdate anyway? (Y/N)"
    if ($updateAnyway -ne "Y" -and $updateAnyway -ne "y") {
        exit 0
    }
} else {
    Write-ColorOutput "`nNew version available!" "Green"
    $confirm = Read-Host "`nContinue with update? (Y/N)"
    if ($confirm -ne "Y" -and $confirm -ne "y") {
        exit 0
    }
}

# Update GOST binaries
if (-not (Download-GostBinaries -Version $latestVersion -Tag $latestTag)) {
    Write-ColorOutput "`nPress any key to exit..." "Yellow"
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
Write-ColorOutput "      Update Complete!" "Green"
Write-ColorOutput "========================================`n" "Green"

Write-ColorOutput "`nPress any key to exit..." "Yellow"
pause
