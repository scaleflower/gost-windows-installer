#!/bin/bash
# =============================================================================
# Update External Dependencies Script
# Purpose: Automatically update GOST and gost-ui in external/ directory
# Usage: bash update-external.sh
# =============================================================================

set -e

# Configuration
GITHUB_REPO_GOST="go-gost/gost"
GITHUB_REPO_GOST_UI="go-gost/gost-ui"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTERNAL_DIR="$SCRIPT_DIR/external"
GOST_DIR="$EXTERNAL_DIR/gost"
GOST_SOURCE_DIR="$GOST_DIR/gost-master"
GOST_UI_DIR="$EXTERNAL_DIR/gost-ui"
VERSIONS_FILE="$EXTERNAL_DIR/VERSIONS.txt"
DOWNLOAD_DIR="/tmp/gost_update"

# Detect system language
if locale | grep -q "zh_CN"; then
    IS_CHINESE=true
else
    IS_CHINESE=false
fi

# Localization
if $IS_CHINESE; then
    MSG_TITLE="更新外部依赖"
    MSG_FETCHING="正在获取最新版本信息..."
    MSG_CURRENT="当前版本: %s"
    MSG_LATEST="最新版本: %s"
    MSG_UPTODATE="已是最新版本"
    MSG_NEW="发现新版本!"
    MSG_DOWNLOADING="正在下载 %s..."
    MSG_COMPLETE="下载完成"
    MSG_FAILED="下载失败: %s"
    MSG_UPDATING="正在更新源码..."
    MSG_UPDATED="源码已更新"
    MSG_VERSIONS="正在更新版本文件..."
    MSG_VERSIONS_UPDATED="版本文件已更新: %s"
    MSG_ERROR="错误"
    MSG_COMPLETE="更新完成!"
    MSG_PRESS="按回车键退出..."
    MSG_CONTINUE="继续更新?
else
    MSG_TITLE="Update External Dependencies"
    MSG_FETCHING="Fetching latest version info..."
    MSG_CURRENT="Current version: %s"
    MSG_LATEST="Latest version: %s"
    MSG_UPTODATE="Already up to date"
    MSG_NEW="New version available!"
    MSG_DOWNLOADING="Downloading %s..."
    MSG_COMPLETE="Download complete"
    MSG_FAILED="Download failed: %s"
    MSG_UPDATING="Updating source code..."
    MSG_UPDATED="Source code updated"
    MSG_VERSIONS="Updating versions file..."
    MSG_VERSIONS_UPDATED="Versions file updated: %s"
    MSG_ERROR="Error"
    MSG_COMPLETE="Update complete!"
    MSG_PRESS="Press Enter to exit..."
    MSG_CONTINUE="Continue with update?
fi

# Color output
print_color() {
    local color=$1
    local message=$2
    case $color in
        red) echo -e "\033[0;31m$message\033[0m" ;;
        green) echo -e "\033[0;32m$message\033[0m" ;;
        yellow) echo -e "\033[1;33m$message\033[0m" ;;
        cyan) echo -e "\033[0;36m$message\033[0m" ;;
        *) echo "$message" ;;
    esac
}

# Get latest GOST release version
get_latest_gost_version() {
    print_color cyan "$MSG_FETCHING"
    local api_url="https://api.github.com/repos/$GITHUB_REPO_GOST/releases/latest"
    local response=$(curl -s "$api_url")
    echo "$response"
}

# Get current version from VERSIONS.txt
get_current_version() {
    if [[ -f "$VERSIONS_FILE" ]]; then
        if grep -q "版本: v" "$VERSIONS_FILE"; then
            grep "版本: v" "$VERSIONS_FILE" | sed -E 's/.*v([0-9.]+).*/\1/'
        fi
    fi
}

# Download GOST release binaries
download_gost_binaries() {
    local tag=$1
    local version=${tag#v}

    printf "\n"
    print_color cyan "========================================"
    print_color cyan "      Downloading GOST Binaries"
    print_color cyan "========================================"
    printf "\n"

    mkdir -p "$DOWNLOAD_DIR"

    # Platforms and architectures to download
    declare -A platforms=(
        ["linux_amd64"]="tar.gz"
        ["linux_386"]="tar.gz"
        ["linux_arm64"]="tar.gz"
        ["windows_amd64"]="zip"
        ["windows_386"]="zip"
        ["windows_arm64"]="zip"
    )

    for platform in "${!platforms[@]}"; do
        local ext="${platforms[$platform]}"
        local filename="gost_${version}_${platform}.${ext}"
        local download_url="https://github.com/$GITHUB_REPO_GOST/releases/download/$tag/$filename"
        local output_file="$DOWNLOAD_DIR/$filename"

        printf "$MSG_DOWNLOADING\n" "$filename"
        if curl -L -o "$output_file" "$download_url"; then
            print_color green "  OK"
        else
            print_color red "  $MSG_FAILED"
            return 1
        fi
    done

    # Copy to external directory
    printf "\n"
    print_color cyan "Copying files to external directory..."
    cp "$DOWNLOAD_DIR"/*.tar.gz "$EXTERNAL_DIR/" 2>/dev/null || true
    cp "$DOWNLOAD_DIR"/*.zip "$EXTERNAL_DIR/" 2>/dev/null || true

    # Clean up old version files
    print_color cyan "Cleaning up old version files..."
    find "$EXTERNAL_DIR" -name "gost_*.tar.gz" ! -name "*${version}*" -delete 2>/dev/null || true
    find "$EXTERNAL_DIR" -name "gost_*.zip" ! -name "*${version}*" -delete 2>/dev/null || true

    # Clean temp directory
    rm -rf "$DOWNLOAD_DIR"

    print_color green "$MSG_COMPLETE"
    return 0
}

# Update GOST source code
update_gost_source() {
    local tag=$1

    printf "\n"
    print_color cyan "========================================"
    print_color cyan "      Updating GOST Source"
    print_color cyan "========================================"
    printf "\n"

    if [[ -d "$GOST_SOURCE_DIR/.git" ]]; then
        # Update existing git repository
        print_color yellow "Updating existing git repository..."
        cd "$GOST_SOURCE_DIR"
        git fetch origin
        git checkout "$tag"
        git pull origin "$tag"
        cd - > /dev/null
        print_color green "$MSG_UPDATED"
    else
        # Clone new repository
        print_color yellow "Cloning GOST repository..."
        mkdir -p "$GOST_DIR"
        git clone --depth 1 --branch "$tag" "https://github.com/$GITHUB_REPO_GOST.git" "$GOST_SOURCE_DIR"
        print_color green "$MSG_UPDATED"
    fi
}

# Update gost-ui source code
update_gost_ui_source() {
    printf "\n"
    print_color cyan "========================================"
    print_color cyan "      Updating gost-ui Source"
    print_color cyan "========================================"
    printf "\n"

    if [[ -d "$GOST_UI_DIR/.git" ]]; then
        # Update existing git repository
        print_color yellow "Updating existing git repository..."
        cd "$GOST_UI_DIR"
        git fetch origin
        local latest_commit=$(git rev-parse origin/master)
        git checkout master
        git pull origin master
        cd - > /dev/null
        print_color green "$MSG_UPDATED (commit: ${latest_commit:0:7})"
        echo "$latest_commit"
    else
        # Clone new repository
        print_color yellow "Cloning gost-ui repository..."
        # Backup existing directory if it's not a git repo
        if [[ -d "$GOST_UI_DIR" ]]; then
            local backup_dir="$GOST_UI_DIR.bak"
            print_color yellow "Backing up existing directory to: $backup_dir"
            mv "$GOST_UI_DIR" "$backup_dir"
        fi
        git clone --depth 1 --branch master "https://github.com/$GITHUB_REPO_GOST_UI.git" "$GOST_UI_DIR"
        local latest_commit=$(git -C "$GOST_UI_DIR" rev-parse HEAD)
        print_color green "$MSG_UPDATED (commit: ${latest_commit:0:7})"
        echo "$latest_commit"
    fi
}

# Update VERSIONS.txt file
update_versions_file() {
    local gost_version=$1
    local gost_ui_commit=$2
    local date=$(date +%Y-%m-%d)

    printf "\n"
    print_color cyan "========================================"
    print_color cyan "      Updating VERSIONS.txt"
    print_color cyan "========================================"
    printf "\n"

    cat > "$VERSIONS_FILE" << EOF
# External Dependencies
# 下载/更新时间: $date

## GOST
- 版本: v$gost_version
- 仓库: https://github.com/go-gost/gost
- 源码目录: gost/gost-master/
- Release 文件:
  * gost_${gost_version}_linux_386.tar.gz
  * gost_${gost_version}_linux_amd64.tar.gz
  * gost_${gost_version}_linux_arm64.tar.gz
  * gost_${gost_version}_windows_386.zip
  * gost_${gost_version}_windows_amd64.zip
  * gost_${gost_version}_windows_arm64.zip

## gost-ui
- 版本: master (commit: $gost_ui_commit)
- 仓库: https://github.com/go-gost/gost-ui
- 源码目录: gost-ui/
EOF

    printf "$MSG_VERSIONS_UPDATED\n" "$VERSIONS_FILE"
}

# =============================================================================
# Main
# =============================================================================

clear
printf "\n"
print_color cyan "========================================"
print_color cyan "      $MSG_TITLE"
print_color cyan "========================================"
printf "\n"

# Check if git is available
if ! command -v git &> /dev/null; then
    print_color red "Error: Git not found. Please install Git first."
    printf "\n"
    read -p "$MSG_PRESS"
    exit 1
fi

# Get version info
version_info=$(get_latest_gost_version)
if [[ -z "$version_info" ]]; then
    read -p "$MSG_PRESS"
    exit 1
fi

latest_tag=$(echo "$version_info" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
latest_version=${latest_tag#v}

# Show version comparison
current_version=$(get_current_version)
printf "$MSG_CURRENT\n" "${current_version:-None}"
printf "$MSG_LATEST\n" "$latest_tag"

if [[ "$current_version" == "$latest_version" ]]; then
    print_color yellow "$MSG_UPTODATE"
    printf "\n"
    read -p "$MSG_CONTINUE" confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        read -p "$MSG_PRESS"
        exit 0
    fi
else
    print_color green "$MSG_NEW"
    printf "\n"
    read -p "$MSG_CONTINUE" confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        read -p "$MSG_PRESS"
        exit 0
    fi
fi

# Update GOST binaries
if ! download_gost_binaries "$latest_tag"; then
    read -p "$MSG_PRESS"
    exit 1
fi

# Update GOST source
update_gost_source "$latest_tag"

# Update gost-ui source
gost_ui_commit=$(update_gost_ui_source)

# Update VERSIONS.txt
update_versions_file "$latest_version" "$gost_ui_commit"

printf "\n"
print_color green "========================================"
print_color green "      $MSG_COMPLETE"
print_color green "========================================"
printf "\n"

read -p "$MSG_PRESS"
