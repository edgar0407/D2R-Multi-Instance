@echo off
:: ==========================================
:: D2R Multi-Instance Launcher v1.0.0 - Debug Mode
:: ==========================================

echo ========================================
echo   D2R Launcher v1.0.0 - DEBUG MODE
echo ========================================
echo.
echo Debug mode shows additional diagnostics
echo including account and password length info
echo.
pause
powershell.exe -ExecutionPolicy Bypass -File "%~dp0D2R_Launcher.ps1" -Debug

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Script Error - Code: %ERRORLEVEL%
    pause
)

