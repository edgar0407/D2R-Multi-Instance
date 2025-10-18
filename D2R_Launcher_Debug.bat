@echo off
chcp 65001 >nul
echo ========================================
echo   D2R 多開啟動器 - 除錯模式
echo ========================================
echo.
echo 除錯模式會顯示額外的診斷資訊
echo 包含帳號、密碼長度等敏感資訊
echo.
pause
powershell.exe -ExecutionPolicy Bypass -File "%~dp0D2R_Launcher.ps1" -Debug
