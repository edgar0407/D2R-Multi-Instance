@echo off
REM chcp 65001 >nul
:: ==========================================
:: D2R 多開啟動器 - 啟動腳本
:: ==========================================

echo ========================================
echo   D2R 多開啟動器 vb0.9.1
echo ========================================
echo.

:: 檢查並解除檔案封鎖 (針對從 GitHub 下載的情況)
echo [1/2] 檢查檔案封鎖狀態...
powershell.exe -ExecutionPolicy Bypass -Command "if (Get-Item '%~dp0D2R_Launcher.ps1' -Stream Zone.Identifier -ErrorAction SilentlyContinue) { Write-Host '      偵測到檔案被封鎖，正在解除...' -ForegroundColor Yellow; Get-ChildItem -Path '%~dp0' -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue; Write-Host '      ? 檔案封鎖已解除' -ForegroundColor Green } else { Write-Host '      ? 檔案狀態正常' -ForegroundColor Green }"

echo.
echo [2/2] 正在啟動 PowerShell 腳本...
echo.

:: 啟動 PowerShell 腳本
powershell.exe -ExecutionPolicy Bypass -File "%~dp0D2R_Launcher.ps1"

:: 只在發生真正的錯誤時才顯示錯誤訊息
:: 注意: 提權重啟時 ERRORLEVEL 為 0，所以不會觸發錯誤訊息
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ========================================
    echo   執行發生錯誤 - 錯誤代碼: %ERRORLEVEL%
    echo ========================================
    echo.
    echo 可能的原因:
    echo   1. 腳本執行過程中發生錯誤
    echo   2. 缺少必要檔案 config.ini 或 handle64.exe
    echo   3. 設定檔格式錯誤
    echo.
    echo 建議: 請使用 D2R_Launcher_Debug.bat 查看詳細錯誤訊息
    echo.
    pause
)
