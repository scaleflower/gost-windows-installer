@echo off
:: =============================================================================
:: GOST Windows 快速安装批处理脚本
:: 用途: 快捷方式调用 PowerShell 安装脚本
:: =============================================================================

setlocal

echo ========================================
:: 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [错误] 请以管理员身份运行此脚本!
    echo 右键点击脚本，选择"以管理员身份运行"
    pause
    exit /b 1
)

echo.
echo 正在启动 GOST 安装程序...
echo.

:: 执行 PowerShell 安装脚本
PowerShell -ExecutionPolicy Bypass -NoProfile -File "%~dp0install.ps1"

if %errorLevel% equ 0 (
    echo.
    echo ========================================
    echo   安装成功!
    echo ========================================
) else (
    echo.
    echo ========================================
    echo   安装失败，请检查错误信息
    echo ========================================
)

echo.
pause
