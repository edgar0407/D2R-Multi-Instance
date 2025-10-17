@echo off
chcp 950 >nul 2>&1
title D2R 多開啟動器

echo ========================================
echo    正在啟動 D2R 多開啟動器...
echo ========================================
echo.

REM 檢查是否以管理員權限執行
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo 錯誤: 需要管理員權限！
    echo 請右鍵點擊此檔案，選擇「以系統管理員身分執行」
    echo.
    pause
    exit /b 1
)

REM 執行 PowerShell 腳本
powershell -ExecutionPolicy Bypass -File "%~dp0D2R_Launcher.ps1"

pause
