@echo off
chcp 950 >nul 2>&1
title D2R �h�}�Ұʾ�

echo ========================================
echo    ���b�Ұ� D2R �h�}�Ұʾ�...
echo ========================================
echo.

REM �ˬd�O�_�H�޲z���v������
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ���~: �ݭn�޲z���v���I
    echo �Хk���I�����ɮסA��ܡu�H�t�κ޲z����������v
    echo.
    pause
    exit /b 1
)

REM ���� PowerShell �}��
powershell -ExecutionPolicy Bypass -File "%~dp0D2R_Launcher.ps1"

pause
