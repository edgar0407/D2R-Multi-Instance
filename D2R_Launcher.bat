@echo off
:: ==========================================
:: D2R Multi-Instance Launcher v1.0.0
:: ==========================================

echo ========================================
echo   D2R Multi-Instance Launcher v1.0.0
echo ========================================
echo.

:: Check and unblock files (for GitHub downloads)
echo [1/2] Checking file block status...
powershell.exe -ExecutionPolicy Bypass -Command "if (Get-Item '%~dp0D2R_Launcher.ps1' -Stream Zone.Identifier -ErrorAction SilentlyContinue) { Write-Host '      File blocked, unblocking...' -ForegroundColor Yellow; Get-ChildItem -Path '%~dp0' -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue; Write-Host '      OK - Files unblocked' -ForegroundColor Green } else { Write-Host '      OK - Files are normal' -ForegroundColor Green }"

echo.
echo [2/2] Starting PowerShell script...
echo.

:: Launch PowerShell script
powershell.exe -ExecutionPolicy Bypass -File "%~dp0D2R_Launcher.ps1"

:: Error handling
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ========================================
    echo   Script Error - Code: %ERRORLEVEL%
    echo ========================================
    echo.
    echo Possible causes:
    echo   1. Script execution error
    echo   2. Missing config.ini or handle64.exe
    echo   3. Config file format error
    echo.
    echo Tip: Use D2R_Launcher_Debug.bat for details
    echo.
    pause
)

