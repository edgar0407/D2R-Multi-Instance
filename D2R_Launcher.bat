@echo off
REM chcp 65001 >nul
:: ==========================================
:: D2R �h�}�Ұʾ� - �Ұʸ}��
:: ==========================================

echo ========================================
echo   D2R �h�}�Ұʾ� vb0.9.1
echo ========================================
echo.

:: �ˬd�øѰ��ɮ׫��� (�w��q GitHub �U�������p)
echo [1/2] �ˬd�ɮ׫��ꪬ�A...
powershell.exe -ExecutionPolicy Bypass -Command "if (Get-Item '%~dp0D2R_Launcher.ps1' -Stream Zone.Identifier -ErrorAction SilentlyContinue) { Write-Host '      �������ɮ׳Q����A���b�Ѱ�...' -ForegroundColor Yellow; Get-ChildItem -Path '%~dp0' -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue; Write-Host '      ? �ɮ׫���w�Ѱ�' -ForegroundColor Green } else { Write-Host '      ? �ɮת��A���`' -ForegroundColor Green }"

echo.
echo [2/2] ���b�Ұ� PowerShell �}��...
echo.

:: �Ұ� PowerShell �}��
powershell.exe -ExecutionPolicy Bypass -File "%~dp0D2R_Launcher.ps1"

:: �u�b�o�ͯu�������~�ɤ~��ܿ��~�T��
:: �`�N: ���v���Ү� ERRORLEVEL �� 0�A�ҥH���|Ĳ�o���~�T��
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ========================================
    echo   ����o�Ϳ��~ - ���~�N�X: %ERRORLEVEL%
    echo ========================================
    echo.
    echo �i�઺��]:
    echo   1. �}������L�{���o�Ϳ��~
    echo   2. �ʤ֥��n�ɮ� config.ini �� handle64.exe
    echo   3. �]�w�ɮ榡���~
    echo.
    echo ��ĳ: �Шϥ� D2R_Launcher_Debug.bat �d�ݸԲӿ��~�T��
    echo.
    pause
)
