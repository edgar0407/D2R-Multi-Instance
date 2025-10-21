@echo off
chcp 65001 >nul
:: ==========================================
:: D2R 多開啟動器 - 啟動腳本
:: ==========================================

echo ========================================
echo   D2R 多開啟動器 vb0.9.1
echo ========================================
echo.

:: 檢查並解除檔案封鎖 (針對從 GitHub 下載的情況)
echo [1/2] 檢查檔案封鎖狀態...
powershell.exe -ExecutionPolicy Bypass -Command "if (Get-Item '%~dp0D2R_Launcher.ps1' -Stream Zone.Identifier -ErrorAction SilentlyContinue) { Write-Host '      偵測到檔案被封鎖，正在解除...' -ForegroundColor Yellow; Get-ChildItem -Path '%~dp0' -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue; Write-Host '      ✓ 檔案封鎖已解除' -ForegroundColor Green } else { Write-Host '      ✓ 檔案狀態正常' -ForegroundColor Green }"

echo.
echo [2/2] 正在啟動 PowerShell 腳本...
echo.

:: 啟動 PowerShell 腳本
powershell.exe -ExecutionPolicy Bypass -File "%~dp0D2R_Launcher.ps1"

:: 檢查執行結果
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ========================================
    echo   執行結束 (錯誤代碼: %ERRORLEVEL%)
    echo ========================================
    echo.
    echo 可能的原因:
    echo   1. 使用者拒絕 UAC 權限提示
    echo   2. 腳本執行過程中發生錯誤
    echo   3. 缺少必要檔案 (config.ini, handle64.exe 等)
    echo.
    echo 建議: 請使用 D2R_Launcher_Debug.bat 查看詳細錯誤訊息
    echo.
    pause
)
