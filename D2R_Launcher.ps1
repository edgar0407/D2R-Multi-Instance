# ==========================================
# D2R 多開啟動器
# ==========================================

#Requires -RunAsAdministrator

# ==========================================
# 設定 1 of 2: 帳號設定 (請自行修改)
# ==========================================
$Accounts = @(
    @{
        Username = "帳號1"
        Password = "密碼1"
        DisplayName = "小土"
        Server = "kr"
        LaunchArgs = "-mod LiYuiMod -txt -w"
    }
    @{
        Username = "帳號2"
        Password = "密碼2"
        DisplayName = "小佑"
        Server = "kr"
        LaunchArgs = "-mod LiYuiMod -txt -w"
    }
)

# ==========================================
# 設定 2 of 2: 路徑設定
# ==========================================
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Handle.exe 路徑
$HandleExePath = "D:\D2R多開\Handle\handle64.exe"
$TempFilePath = "D:\D2R多開\Handle\handles.txt"

# D2R 遊戲路徑
$D2RGamePath = "D:\Diablo II Resurrected\D2R.exe"

# 日誌路徑
$LogDir = Join-Path $ScriptPath "logs"

# ==========================================
# 伺服器地址對應表
# ==========================================
$ServerAddresses = @{
    "us" = "us.actual.battle.net"
    "eu" = "eu.actual.battle.net"
    "kr" = "kr.actual.battle.net"
}

# ==========================================
# Windows API 定義 - 用於修改視窗標題
# ==========================================
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class WindowAPI {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern bool SetWindowText(IntPtr hWnd, string lpString);

    [DllImport("user32.dll")]
    public static extern IntPtr GetWindowThreadProcessId(IntPtr hWnd, out int lpdwProcessId);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
}
"@

# ==========================================
# 函數: 取得所有 D2R 視窗的 Handle (返回 Handle 陣列)
# ==========================================
function Get-D2RWindowHandles {
    # 定義為 script 作用域變數，讓 callback 可以存取
    $script:Handles = New-Object System.Collections.ArrayList

    $Callback = {
        param([IntPtr]$hWnd, [IntPtr]$lParam)

        $IsVisible = [WindowAPI]::IsWindowVisible($hWnd)

        if ($IsVisible) {
            $Length = [WindowAPI]::GetWindowTextLength($hWnd)
            if ($Length -gt 0) {
                $StringBuilder = New-Object System.Text.StringBuilder($Length + 1)
                [WindowAPI]::GetWindowText($hWnd, $StringBuilder, $StringBuilder.Capacity) | Out-Null
                $Title = $StringBuilder.ToString()

                # 檢查是否為 D2R 視窗
                if ($Title -match "Diablo.*Resurrected" -or $Title -eq "Diablo II: Resurrected") {
                    [void]$script:Handles.Add($hWnd)
                }
            }
        }
        return $true
    }

    $CallbackDelegate = [WindowAPI+EnumWindowsProc]$Callback
    [WindowAPI]::EnumWindows($CallbackDelegate, [IntPtr]::Zero) | Out-Null

    return $script:Handles
}

# ==========================================
# 函數: 找出新視窗並設定標題
# ==========================================
function Set-NewD2RWindowTitle {
    param(
        [System.Collections.ArrayList]$OldHandles,
        [string]$NewTitle,
        [int]$MaxRetries = 10,
        [int]$RetryDelaySeconds = 1
    )

    Write-Host "  [偵測] 開始尋找新的 D2R 視窗..." -ForegroundColor Gray
    Write-Host "  [偵測] 啟動前已有 $($OldHandles.Count) 個 D2R 視窗" -ForegroundColor Gray

    for ($retry = 1; $retry -le $MaxRetries; $retry++) {
        try {
            # 取得當前所有 D2R 視窗
            $CurrentHandles = Get-D2RWindowHandles

            Write-Host "  [偵測] 第 $retry 次檢查，目前有 $($CurrentHandles.Count) 個 D2R 視窗" -ForegroundColor Gray

            # 找出新視窗（不在舊清單中且存在的 Handle）
            foreach ($Handle in $CurrentHandles) {
                if ($Handle -notin $OldHandles) {
                    # 取得視窗資訊
                    $ProcID = 0
                    [WindowAPI]::GetWindowThreadProcessId($Handle, [ref]$ProcID) | Out-Null

                    $Length = [WindowAPI]::GetWindowTextLength($Handle)
                    if ($Length -gt 0) {
                        $StringBuilder = New-Object System.Text.StringBuilder($Length + 1)
                        [WindowAPI]::GetWindowText($Handle, $StringBuilder, $StringBuilder.Capacity) | Out-Null
                        $OldTitle = $StringBuilder.ToString()
                    } else {
                        $OldTitle = "(無標題)"
                    }

                    Write-Host "  [偵測] 找到新視窗 - Handle: $Handle, PID: $ProcID, 原標題: '$OldTitle'" -ForegroundColor Gray

                    # 設定新標題
                    $Result = [WindowAPI]::SetWindowText($Handle, $NewTitle)
                    if ($Result) {
                        Write-Host "  [成功] 成功設定視窗標題為: '$NewTitle'" -ForegroundColor Gray
                        Write-Log "成功設定視窗標題: '$NewTitle' (Handle: $Handle, PID: $ProcID, 嘗試: $retry)" "SUCCESS"
                        return $true
                    } else {
                        Write-Host "  [警告] SetWindowText 失敗" -ForegroundColor Gray
                        Write-Log "SetWindowText 失敗 (Handle: $Handle)" "WARNING"
                    }
                }
            }

            if ($retry -lt $MaxRetries) {
                Write-Host "  [偵測] 第 $retry 次嘗試：尚未找到新視窗，等待 $RetryDelaySeconds 秒後重試..." -ForegroundColor Gray
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
        catch {
            Write-Host "  [錯誤] 發生例外 (嘗試: $retry): $_" -ForegroundColor Gray
            Write-Log "設定視窗標題時發生例外 (嘗試: $retry): $_" "ERROR"
        }
    }

    Write-Log "設定視窗標題失敗：已達最大嘗試次數" "ERROR"
    return $false
}

# ==========================================
# 檢查必要檔案是否存在
# ==========================================
if (-not (Test-Path $HandleExePath)) {
    Write-Host "錯誤: 找不到 handle64.exe，路徑: $HandleExePath" -ForegroundColor Red
    Read-Host "按 Enter 退出"
    exit 1
}

if (-not (Test-Path $D2RGamePath)) {
    Write-Host "錯誤: 找不到 D2R 遊戲，路徑: $D2RGamePath" -ForegroundColor Red
    Read-Host "按 Enter 退出"
    exit 1
}

# 建立日誌目錄
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

# ==========================================
# 函數: 寫入日誌
# ==========================================
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogFile = Join-Path $LogDir "D2R_Launch_$(Get-Date -Format 'yyyyMMdd').log"
    $LogMessage = "[$Timestamp] [$Level] $Message"

    # 使用 mutex 避免多進程同時寫入日誌檔案發生錯誤
    try {
        $Mutex = New-Object System.Threading.Mutex($false, "D2RLauncherLogMutex")
        [void]$Mutex.WaitOne()
        Add-Content -Path $LogFile -Value $LogMessage -ErrorAction SilentlyContinue
        $Mutex.ReleaseMutex()
        $Mutex.Dispose()
    }
    catch {
        # 忽略日誌寫入錯誤
    }
}

# ==========================================
# 函數: 關閉 D2R Handles
# ==========================================
function Close-D2RHandles {
    try {
        # 執行 handle.exe 輸出所有進程資訊
        $HandleOutput = & $HandleExePath -a "Check For Other Instances" -nobanner 2>&1

        if ($LASTEXITCODE -ne 0 -and $HandleOutput -notmatch "No matching handles found") {
            Write-Log "警告: handle.exe 執行異常" "WARNING"
        }

        # 儲存輸出到檔案
        $HandleOutput | Out-File -FilePath $TempFilePath -Encoding UTF8

        # 使用 tokens=3,6 方法來關閉所有 handles
        $CloseCount = 0
        $Lines = Get-Content $TempFilePath

        foreach ($Line in $Lines) {
            # 以空白分隔取得第 3 和第 6 個 token (ProcessID 和 Handle ID)
            $Tokens = $Line -split '\s+' | Where-Object { $_ -ne '' }

            if ($Tokens.Count -ge 6) {
                $ProcessID = $Tokens[2]        # Token 3 (0-indexed = 2)
                $HandleIDRaw = $Tokens[5]      # Token 6 (0-indexed = 5)
                $HandleID = $HandleIDRaw -replace ':',''  # 移除冒號

                # 確認 ProcessID 是數字、HandleID 是十六進制
                if ($ProcessID -match '^\d+$' -and $HandleID -match '^[0-9A-Fa-f]+$') {
                    Write-Log "發現 handle - 進程 ID: $ProcessID, Handle ID: $HandleID"

                    # 關閉 handle
                    $CloseResult = & $HandleExePath -p $ProcessID -c $HandleID -y 2>&1

                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "成功關閉 handle: $HandleID" "SUCCESS"
                        $CloseCount++
                    } else {
                        Write-Log "無法關閉 handle: $HandleID - $CloseResult" "ERROR"
                    }
                }
            }
        }

        if ($CloseCount -eq 0) {
            Write-Host "  [資訊] 沒有需要關閉的 handles" -ForegroundColor Gray
            Write-Log "沒有發現需要關閉的 handles"
        } else {
            Write-Host "  [資訊] 成功關閉 $CloseCount 個 handles" -ForegroundColor Green
            Write-Log "總共關閉了 $CloseCount 個 handles" "SUCCESS"
        }

        return $true
    }
    catch {
        Write-Host "  [錯誤] 關閉 handles 時發生錯誤: $_" -ForegroundColor Red
        Write-Log "關閉 handles 時發生錯誤: $_" "ERROR"
        return $false
    }
}

# ==========================================
# 函數: 啟動 D2R
# ==========================================
function Start-D2R {
    param(
        [string]$Username,
        [string]$Password,
        [string]$DisplayName,
        [string]$Server = "",
        [string]$LaunchArgs = "",
        [int]$AccountNumber = 0
    )

    Write-Host ""
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "  正在啟動: $DisplayName" -ForegroundColor Yellow
    Write-Host "================================================" -ForegroundColor Cyan

    try {
        # 在啟動前，記錄現有視窗的 D2R 視窗
        $WindowsBeforeLaunch = Get-D2RWindowHandles
        Write-Host "  [偵測] 啟動前已有 $($WindowsBeforeLaunch.Count) 個 D2R 視窗" -ForegroundColor Gray

        # 構建遊戲啟動參數列表
        $ArgsList = @()
        $ArgsList += "-username"
        $ArgsList += $Username
        $ArgsList += "-password"
        $ArgsList += $Password

        # 加入伺服器地址
        if ($Server -and $ServerAddresses.ContainsKey($Server.ToLower())) {
            $ServerAddress = $ServerAddresses[$Server.ToLower()]
            $ArgsList += "-address"
            $ArgsList += $ServerAddress
            Write-Host "  [伺服器] $Server" -ForegroundColor Cyan
            Write-Log "伺服器: $Server ($ServerAddress)" "INFO"
        }

        # 加入自訂參數
        if ($LaunchArgs) {
            $LaunchArgs.Split(' ') | ForEach-Object {
                if ($_.Trim()) {
                    $ArgsList += $_.Trim()
                }
            }
            Write-Host "  [啟動參數] $LaunchArgs" -ForegroundColor Cyan
            Write-Log "使用參數: $LaunchArgs" "INFO"
        }

        # 啟動遊戲
        Write-Host "  [執行] 正在啟動遊戲..." -ForegroundColor White
        $ProcessInfo = Start-Process -FilePath $D2RGamePath -ArgumentList $ArgsList -PassThru

        if ($ProcessInfo) {
            Write-Host "  [成功] 遊戲已啟動 (PID: $($ProcessInfo.Id))" -ForegroundColor Green
            Write-Log "D2R 進程已啟動 - PID: $($ProcessInfo.Id)" "SUCCESS"
            Write-Log "D2R 已啟動 - $DisplayName" "SUCCESS"
        } else {
            Write-Host "  [警告] 無法取得進程資訊" -ForegroundColor Yellow
            Write-Log "無法取得進程資訊" "WARNING"
        }

        # 等待遊戲視窗初始化
        Write-Host "  [等待] 遊戲視窗初始化中 (3 秒)..." -ForegroundColor White
        Start-Sleep -Seconds 3

        # 設定新視窗的標題
        if ($AccountNumber -gt 0) {
            $WindowTitle = "D2R: $AccountNumber - $DisplayName"
            Write-Host "  [執行] 設定視窗標題: $WindowTitle" -ForegroundColor White
            $TitleResult = Set-NewD2RWindowTitle -OldHandles $WindowsBeforeLaunch -NewTitle $WindowTitle -MaxRetries 10 -RetryDelaySeconds 1
            if ($TitleResult) {
                Write-Host "  [成功] 視窗標題已設定" -ForegroundColor Green
            } else {
                Write-Host "  [警告] 無法設定視窗標題" -ForegroundColor Yellow
            }
        }

        # 關閉 handle（允許下一個實例啟動）
        Write-Host "  [執行] 檢查並關閉 handle..." -ForegroundColor White
        if (-not (Close-D2RHandles)) {
            Write-Host "  [警告] 無法關閉 handles" -ForegroundColor Yellow
            Write-Log "無法關閉 handles" "WARNING"
        }

        # 等待後繼續
        Write-Host "  [等待] 準備下一個遊戲 (3 秒)..." -ForegroundColor White
        Write-Host "================================================" -ForegroundColor Cyan
        Start-Sleep -Seconds 3
    }
    catch {
        Write-Host "  [錯誤] 啟動失敗: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "啟動 D2R 時發生錯誤: $_" "ERROR"
    }
}

# ==========================================
# 主選單
# ==========================================
function Show-Menu {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "         D2R 多開啟動器" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "可用帳號:" -ForegroundColor White
    Write-Host ""

    for ($i = 0; $i -lt $Accounts.Count; $i++) {
        Write-Host "  [$($i + 1)] $($Accounts[$i].DisplayName)" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "  [A] 啟動所有帳號" -ForegroundColor Green
    Write-Host "  [C] 僅關閉 Handles (不啟動遊戲)" -ForegroundColor Magenta
    Write-Host "  [Q] 退出" -ForegroundColor Red
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
}

# 主迴圈
do {
    Show-Menu
    $Choice = Read-Host "請選擇"

    switch ($Choice.ToUpper()) {
        "A" {
            Write-Host ""
            Write-Host "開始啟動所有帳號..." -ForegroundColor Green
            for ($i = 0; $i -lt $Accounts.Count; $i++) {
                $Account = $Accounts[$i]
                Start-D2R -Username $Account.Username -Password $Account.Password -DisplayName $Account.DisplayName -Server $Account.Server -LaunchArgs $Account.LaunchArgs -AccountNumber ($i + 1)
            }
            Write-Host ""
            Write-Host "所有帳號已啟動完畢！" -ForegroundColor Green
            Read-Host "按 Enter 返回選單"
        }
        "C" {
            Write-Host ""
            Write-Host "執行 Handle 清理作業..." -ForegroundColor Magenta
            Close-D2RHandles
            Write-Host ""
            Read-Host "按 Enter 返回選單"
        }
        "Q" {
            Write-Log "結束程式"
            exit 0
        }
        default {
            if ($Choice -match '^\d+$' -and [int]$Choice -ge 1 -and [int]$Choice -le $Accounts.Count) {
                $AccountIndex = [int]$Choice - 1
                $SelectedAccount = $Accounts[$AccountIndex]
                Start-D2R -Username $SelectedAccount.Username -Password $SelectedAccount.Password -DisplayName $SelectedAccount.DisplayName -Server $SelectedAccount.Server -LaunchArgs $SelectedAccount.LaunchArgs -AccountNumber ([int]$Choice)
                Write-Host ""
                Read-Host "按 Enter 返回選單"
            } else {
                Write-Host ""
                Write-Host "無效選擇！請重新輸入" -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
} while ($true)
