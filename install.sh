#!/bin/bash
# =============================================================================
# GOST Linux Installer/Uninstaller Script
# Purpose: Automatically download, install, uninstall GOST on Linux
# Usage: sudo bash install.sh [install|uninstall|update]
# =============================================================================

set -e

# Configuration
GITHUB_REPO="go-gost/gost"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/gost"
CONFIG_FILE="$CONFIG_DIR/config.json"
SERVICE_NAME="gost"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
DOWNLOAD_DIR="/tmp/gost_install"
LOG_FILE="/var/log/gost-install.log"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Detect system language
if locale | grep -q "zh_CN"; then
    IS_CHINESE=true
else
    IS_CHINESE=false
fi

# Localization
if $IS_CHINESE; then
    MSG_TITLE="GOST Linux 安装程序"
    MSG_SELECT="请选择操作:"
    MSG_INSTALL="1. 安装 GOST"
    MSG_UNINSTALL="2. 卸载 GOST"
    MSG_UPDATE="3. 检查更新"
    MSG_LOG="4. 查看日志"
    MSG_EXIT="5. 退出"
    MSG_ENTER_OPTION="请输入选项 (1-5): "
    MSG_INSTALL_TITLE="正在安装 GOST"
    MSG_UNINSTALL_TITLE="正在卸载 GOST"
    MSG_COMPLETE="完成!"
    FAILED="失败"
    SUCCESS="成功"
    ERROR="错误"
    PRESS_KEY="按回车键返回..."
else
    MSG_TITLE="GOST Linux Installer"
    MSG_SELECT="Select an option:"
    MSG_INSTALL="1. Install GOST"
    MSG_UNINSTALL="2. Uninstall GOST"
    MSG_UPDATE="3. Check Update"
    MSG_LOG="4. View Log"
    MSG_EXIT="5. Exit"
    MSG_ENTER_OPTION="Enter option (1-5): "
    MSG_INSTALL_TITLE="Installing GOST"
    MSG_UNINSTALL_TITLE="Uninstall GOST"
    MSG_COMPLETE="Complete!"
    FAILED="Failed"
    SUCCESS="Success"
    ERROR="Error"
    PRESS_KEY="Press Enter to return..."
fi

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Print colored message
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
    log "$(echo "$message" | sed 's/\x1b\[[0-9;]*m//g')"
}

# Check root privilege
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_color "$RED" "[$ERROR] Please run as root (sudo)"
        exit 1
    fi
}

# Detect system architecture
get_architecture() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            echo "amd64"
            ;;
        i386|i686)
            echo "386"
            ;;
        aarch64)
            echo "arm64"
            ;;
        armv7l)
            echo "arm-7"
            ;;
        *)
            print_color "$RED" "Unsupported architecture: $arch"
            return 1
            ;;
    esac
}

# Get latest version
get_latest_version() {
    local api_url="https://api.github.com/repos/$GITHUB_REPO/releases/latest"
    local version=$(curl -s "$api_url" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    echo "$version"
}

# Download GOST
download_gost() {
    local version=$1
    local arch=$2
    local version_num=${version#v}
    local download_url="https://github.com/$GITHUB_REPO/releases/download/${version}/gost_${version_num}_linux_${arch}.tar.gz"

    print_color "$CYAN" "Download URL: $download_url"

    mkdir -p "$DOWNLOAD_DIR"
    local tar_file="$DOWNLOAD_DIR/gost.tar.gz"

    if curl -L -o "$tar_file" "$download_url"; then
        print_color "$GREEN" "Download $SUCCESS"
        echo "$tar_file"
    else
        print_color "$RED" "Download $FAILED"
        return 1
    fi
}

# Install GOST binary
install_binary() {
    local tar_file=$1

    print_color "$CYAN" "Extracting files..."
    tar -xzf "$tar_file" -C "$DOWNLOAD_DIR"

    local gost_exe=$(find "$DOWNLOAD_DIR" -name "gost" -type f | head -1)
    if [[ -n "$gost_exe" ]]; then
        cp "$gost_exe" "$INSTALL_DIR/gost"
        chmod +x "$INSTALL_DIR/gost"
        print_color "$GREEN" "Installed to: $INSTALL_DIR/gost"
        return 0
    else
        print_color "$RED" "gost binary not found"
        return 1
    fi
}

# Create config file
create_config() {
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" << EOF
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
EOF
    print_color "$GREEN" "Config created: $CONFIG_FILE"
}

# Install systemd service
install_service() {
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=GOST Port Forwarding Service
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/gost -C $CONFIG_FILE
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    print_color "$GREEN" "Service installed: $SERVICE_NAME"
    print_color "$CYAN" "Service commands:"
    echo "  Start:   systemctl start $SERVICE_NAME"
    echo "  Stop:    systemctl stop $SERVICE_NAME"
    echo "  Status:  systemctl status $SERVICE_NAME"
    echo "  Enable:  systemctl enable $SERVICE_NAME"
}

# Configure firewall
configure_firewall() {
    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=8090/tcp 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
        print_color "$GREEN" "Firewall (firewalld) configured: TCP 8090"
    elif command -v ufw &> /dev/null; then
        ufw allow 8090/tcp 2>/dev/null || true
        print_color "$GREEN" "Firewall (ufw) configured: TCP 8090"
    fi
}

# Full installation
install_full() {
    print_color "$CYAN" "========================================"
    print_color "$CYAN" "$MSG_INSTALL_TITLE"
    print_color "$CYAN" "========================================"

    local version=$(get_latest_version)
    if [[ -z "$version" ]]; then
        print_color "$RED" "Failed to get version info"
        read -p "$PRESS_KEY"
        return 1
    fi
    print_color "$GREEN" "Latest version: $version"

    local arch=$(get_architecture)
    if [[ -z "$arch" ]]; then
        read -p "$PRESS_KEY"
        return 1
    fi
    print_color "$GREEN" "Architecture: $arch"

    local tar_file=$(download_gost "$version" "$arch")
    if [[ -z "$tar_file" ]]; then
        read -p "$PRESS_KEY"
        return 1
    fi

    if ! install_binary "$tar_file"; then
        read -p "$PRESS_KEY"
        return 1
    fi

    create_config
    configure_firewall
    install_service

    # Clean up
    rm -rf "$DOWNLOAD_DIR"

    print_color "$GREEN" "========================================"
    print_color "$GREEN" "$MSG_COMPLETE"
    print_color "$GREEN" "========================================"
    print_color "$NC" "Install dir: $INSTALL_DIR/gost"
    print_color "$NC" "Config file: $CONFIG_FILE"
    print_color "$NC" "API address: http://localhost:8090"

    read -p "$PRESS_KEY"
}

# Uninstall GOST
uninstall_gost() {
    print_color "$CYAN" "========================================"
    print_color "$CYAN" "$MSG_UNINSTALL_TITLE"
    print_color "$CYAN" "========================================"

    if $IS_CHINESE; then
        read -p "确认卸载? (y/N): " confirm
    else
        read -p "Confirm uninstall? (y/N): " confirm
    fi

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_color "$YELLOW" "Cancelled"
        read -p "$PRESS_KEY"
        return 0
    fi

    # Stop and disable service
    if systemctl is-active --quiet $SERVICE_NAME 2>/dev/null; then
        systemctl stop $SERVICE_NAME
        print_color "$GREEN" "Service stopped"
    fi

    if systemctl is-enabled --quiet $SERVICE_NAME 2>/dev/null; then
        systemctl disable $SERVICE_NAME
        print_color "$GREEN" "Service disabled"
    fi

    # Remove service file
    if [[ -f "$SERVICE_FILE" ]]; then
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload
        print_color "$GREEN" "Service file removed"
    fi

    # Remove binary
    if [[ -f "$INSTALL_DIR/gost" ]]; then
        rm -f "$INSTALL_DIR/gost"
        print_color "$GREEN" "Binary removed"
    fi

    # Remove config (optional)
    if [[ -d "$CONFIG_DIR" ]]; then
        if $IS_CHINESE; then
            read -p "保留配置文件? (Y/n): " keep_config
        else
            read -p "Keep config files? (Y/n): " keep_config
        fi
        if [[ "$keep_config" == "n" || "$keep_config" == "N" ]]; then
            rm -rf "$CONFIG_DIR"
            print_color "$GREEN" "Config removed"
        fi
    fi

    print_color "$GREEN" "========================================"
    print_color "$GREEN" "$MSG_COMPLETE"
    print_color "$GREEN" "========================================"

    read -p "$PRESS_KEY"
}

# Check update
check_update() {
    print_color "$CYAN" "========================================"
    print_color "$CYAN" "Check Update"
    print_color "$CYAN" "========================================"

    local latest_version=$(get_latest_version)
    if [[ -z "$latest_version" ]]; then
        read -p "$PRESS_KEY"
        return 1
    fi

    local current_version=""
    if [[ -f "$INSTALL_DIR/gost" ]]; then
        current_version=$($INSTALL_DIR/gost -v 2>/dev/null | grep -oP 'gost \K[\d.]+' || echo "unknown")
    fi

    print_color "$CYAN" "Current: $current_version"
    print_color "$CYAN" "Latest:  ${latest_version#v}"

    if [[ "$current_version" == "${latest_version#v}" ]]; then
        print_color "$GREEN" "Already up to date!"
    else
        print_color "$YELLOW" "New version available!"
        if $IS_CHINESE; then
            read -p "现在更新? (y/N): " update_confirm
        else
            read -p "Update now? (y/N): " update_confirm
        fi

        if [[ "$update_confirm" == "y" || "$update_confirm" == "Y" ]]; then
            # Stop service
            systemctl stop $SERVICE_NAME 2>/dev/null || true

            local arch=$(get_architecture)
            local tar_file=$(download_gost "$latest_version" "$arch")
            install_binary "$tar_file"
            rm -rf "$DOWNLOAD_DIR"

            # Start service
            systemctl start $SERVICE_NAME 2>/dev/null || true

            print_color "$GREEN" "Update $SUCCESS!"
        fi
    fi

    read -p "$PRESS_KEY"
}

# View log
view_log() {
    print_color "$CYAN" "========================================"
    if $IS_CHINESE; then
        print_color "$CYAN" "查看日志"
    else
        print_color "$CYAN" "View Log"
    fi
    print_color "$CYAN" "========================================"

    if [[ -f "$LOG_FILE" ]]; then
        echo ""
        tail -50 "$LOG_FILE"
    else
        print_color "$YELLOW" "Log file not found: $LOG_FILE"
    fi

    echo ""
    read -p "$PRESS_KEY"
}

# Show main menu
show_menu() {
    clear
    print_color "$CYAN" ""
    print_color "$CYAN" "========================================"
    print_color "$CYAN" "      $MSG_TITLE"
    print_color "$CYAN" "========================================"
    echo ""
    print_color "$YELLOW" "$MSG_SELECT"
    echo "  $MSG_INSTALL"
    echo "  $MSG_UNINSTALL"
    echo "  $MSG_UPDATE"
    echo "  $MSG_LOG"
    echo "  $MSG_EXIT"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

check_root

# Create log file
touch "$LOG_FILE"
log "GOST Installer started"

# Command line mode
if [[ $# -gt 0 ]]; then
    case "$1" in
        install)
            install_full
            ;;
        uninstall)
            uninstall_gost
            ;;
        update)
            check_update
            ;;
        *)
            echo "Usage: $0 [install|uninstall|update]"
            exit 1
            ;;
    esac
    exit 0
fi

# Interactive mode
while true; do
    show_menu
    read -p "$MSG_ENTER_OPTION" choice

    case "$choice" in
        1)
            install_full
            ;;
        2)
            uninstall_gost
            ;;
        3)
            check_update
            ;;
        4)
            view_log
            ;;
        5)
            print_color "$GREEN" "Goodbye!"
            exit 0
            ;;
        *)
            print_color "$RED" "Invalid option"
            sleep 1
            ;;
    esac
done
