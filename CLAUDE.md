# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **gost-windows-installer** project - an automated installer for GOST (GO Simple Tunnel), a simple and efficient port forwarding/tunnel tool written in Go. The project provides one-click installation scripts for both Windows and Linux platforms, with integrated API support for management via [gost-ui](https://github.com/go-gost/gost-ui).

**Repository**: https://github.com/scaleflower/gost-windows-installer

## Architecture

### Core Components

1. **install-en.ps1** - Windows installer/uninstaller script (PowerShell)
   - Downloads latest GOST binary from GitHub releases
   - Installs GOST to `C:\gost\`
   - Optionally registers as Windows service using `sc.exe`
   - Configures firewall rules for API port 8090
   - Adds installation directory to system PATH

2. **install.sh** - Linux installer/uninstaller script (Bash)
   - Downloads and installs GOST to `/usr/local/bin/`
   - Creates systemd service at `/etc/systemd/system/gost.service`
   - Stores config in `/etc/gost/config.json`

3. **external/** - Contains vendored dependencies:
   - `gost/gost-master/` - GOST source code (v3.2.6)
   - `gost-ui/` - Web UI for GOST management (React/Vue app)

### Key Design Decisions

- **JSON Configuration**: Uses JSON format (not YAML) for compatibility with gost-ui's default save format
- **Native Windows Service**: Uses GOST's built-in `judwhite/go-svc` library - no third-party tools like NSSM required
- **Architecture Detection**: Automatically detects x64/x86/ARM64 via environment variables (`PROCESSOR_ARCHITEW6432`, `PROCESSOR_ARCHITECTURE`)
- **Bilingual Support**: Scripts detect system locale (Chinese/English) and display localized messages

### Default Configuration

The installer generates a default `config.json` with:
- SOCKS5 proxy on port `:10800`
- API server on `0.0.0.0:8090` (for gost-ui management)

## Common Development Tasks

### Testing Windows Installer Locally

```powershell
# Run interactive menu
PowerShell -ExecutionPolicy Bypass -File install-en.ps1

# Run specific action directly
PowerShell -ExecutionPolicy Bypass -File install-en.ps1 install
PowerShell -ExecutionPolicy Bypass -File install-en.ps1 uninstall
PowerShell -ExecutionPolicy Bypass -File install-en.ps1 update
```

### Testing Linux Installer Locally

```bash
# Run interactive menu
sudo bash install.sh

# Run specific action directly
sudo bash install.sh install
sudo bash install.sh uninstall
sudo bash install.sh update
```

### Manual GOST Execution (Windows)

```cmd
cd C:\gost
gost.exe -C config.json
```

### Service Management

**Windows:**
```cmd
net start GostForward
net stop GostForward
sc.exe delete GostForward
```

**Linux:**
```bash
sudo systemctl start gost
sudo systemctl stop gost
sudo systemctl enable gost
sudo systemctl status gost
```

### Using gost-ui

1. Deploy gost-ui on a VPS
2. Access `http://VPS_IP:PORT`
3. Add remote GOST server: `http://JUMPBOX_IP:8090`
4. Configure port forwarding rules via web interface

## Important Constraints

### PowerShell Encoding Issues

Windows PowerShell 5.1 has known issues with UTF-8 files containing non-ASCII characters. The solution is `install-en.ps1` - a pure ASCII version without any Chinese characters. Always use `install-en.ps1` for the primary installer.

### Windows Defender Interference

Windows Defender may block GOST downloads (false positive). The installer:
1. Detects Defender real-time protection status
2. Optionally offers to temporarily disable it during installation
3. Automatically re-enables it after installation completes

### GitHub API Rate Limits

The installer queries GitHub Releases API to fetch the latest version. No authentication token is used, so it's subject to unauthenticated rate limits (60 requests/hour).

### API URL Construction

Download URLs are constructed directly using the standard GitHub format:
```
https://github.com/go-gost/gost/releases/download/v{VERSION}/gost_{VERSION}_windows_{ARCH}.zip
```

This avoids API parsing issues and is more reliable than extracting URLs from release assets.

## External Dependencies

- **GOST**: v3.2.6 - https://github.com/go-gost/gost
- **gost-ui**: master branch - https://github.com/go-gost/gost-ui

See `external/VERSIONS.txt` for current versions.
