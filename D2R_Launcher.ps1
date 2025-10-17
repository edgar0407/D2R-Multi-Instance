# ==========================================
# D2R 多開啟動器
# ==========================================

#Requires -RunAsAdministrator

# ==========================================
# 步驟 1 of 2: 帳號設定 (在此修改)
# ==========================================
$Accounts = @(
    @{
        Username = "帳號1"
        Password = "密碼1"
        DisplayName = "帳號1 顯示名子"
        Server = "kr"
        LaunchArgs = "-mod LiYuiMod -txt -w"
    }
    @{
        Username = "帳號2"
        Password = "密碼2"
        DisplayName = "帳號2 顯示名子"
        Server = "kr"
        LaunchArgs = "-mod LiYuiMod -txt -w"
    }
)

# ==========================================
# 步驟 2 of 2: 目錄設定
# ==========================================
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Handle.exe 路徑
$HandleExePath = "D:\D2R多開\Handle\handle64.exe"
$TempFilePath = "D:\D2R多開\Handle\handles.txt"

# D2R 遊戲路徑
$D2RGamePath = "D:\Diablo II Resurrected\D2R.exe"

# 日誌目錄
$LogDir = Join-Path $ScriptPath "logs"

# ==========================================
# 伺服器位址對應
# ==========================================
$ServerAddresses = @{
    "us" = "us.actual.battle.net"
    "eu" = "eu.actual.battle.net"
    "kr" = "kr.actual.battle.net"
}

# ==========================================
# 驗證必要檔案
# ==========================================
if (-not (Test-Path $HandleExePath)) {
    Write-Host "錯誤: 找不到 handle64.exe，路徑: $HandleExePath" -ForegroundColor Red
    Read-Host "按 Enter 鍵退出"
    exit 1
}

if (-not (Test-Path $D2RGamePath)) {
    Write-Host "錯誤: 找不到 D2R 遊戲，路徑: $D2RGamePath" -ForegroundColor Red
    Read-Host "按 Enter 鍵退出"
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

    # 使用 mutex 避免多個實例同時寫入日誌檔案時發生衝突
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
        # 執行 handle.exe 並輸出到臨時檔案
        $HandleOutput = & $HandleExePath -a "Check For Other Instances" -nobanner 2>&1

        if ($LASTEXITCODE -ne 0 -and $HandleOutput -notmatch "No matching handles found") {
            Write-Log "警告: handle.exe 執行異常" "WARNING"
        }

        # 儲存輸出到檔案
        $HandleOutput | Out-File -FilePath $TempFilePath -Encoding UTF8

        # 使用 tokens=3,6 方法解析並關閉 handles
        $CloseCount = 0
        $Lines = Get-Content $TempFilePath

        foreach ($Line in $Lines) {
            # 用空格分割並取得第 3 和第 6 個 token (ProcessID 和 Handle ID)
            $Tokens = $Line -split '\s+' | Where-Object { $_ -ne '' }

            if ($Tokens.Count -ge 6) {
                $ProcessID = $Tokens[2]        # Token 3 (0-indexed = 2)
                $HandleIDRaw = $Tokens[5]      # Token 6 (0-indexed = 5)
                $HandleID = $HandleIDRaw -replace ':',''  # 移除冒號

                # 驗證 ProcessID 是數字且 HandleID 是十六進位
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
            Write-Host "  [狀態] 沒有需要關閉的 handles" -ForegroundColor Gray
            Write-Log "沒有發現需要關閉的 handles"
        } else {
            Write-Host "  [狀態] 成功關閉 $CloseCount 個 handles" -ForegroundColor Green
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
        [string]$LaunchArgs = ""
    )

    Write-Host ""
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "  啟動帳號: $DisplayName" -ForegroundColor Yellow
    Write-Host "================================================" -ForegroundColor Cyan

    try {
        # 建立完整的啟動參數陣列
        $ArgsList = @()
        $ArgsList += "-username"
        $ArgsList += $Username
        $ArgsList += "-password"
        $ArgsList += $Password

        # 加入伺服器位址
        if ($Server -and $ServerAddresses.ContainsKey($Server.ToLower())) {
            $ServerAddress = $ServerAddresses[$Server.ToLower()]
            $ArgsList += "-address"
            $ArgsList += $ServerAddress
            Write-Host "  [伺服器] $Server" -ForegroundColor Cyan
            Write-Log "伺服器: $Server ($ServerAddress)" "INFO"
        }

        # 加入自訂啟動參數
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
        Write-Host "  [動作] 正在啟動遊戲..." -ForegroundColor White
        $ProcessInfo = Start-Process -FilePath $D2RGamePath -ArgumentList $ArgsList -PassThru

        if ($ProcessInfo) {
            Write-Host "  [成功] 遊戲已啟動 (PID: $($ProcessInfo.Id))" -ForegroundColor Green
            Write-Log "D2R 進程已啟動 - PID: $($ProcessInfo.Id)" "SUCCESS"
            Write-Log "D2R 已啟動 - $DisplayName" "SUCCESS"
        } else {
            Write-Host "  [警告] 無法取得進程資訊" -ForegroundColor Yellow
            Write-Log "無法取得進程資訊" "WARNING"
        }

        # 等待遊戲初始化
        Write-Host "  [等待] 遊戲初始化中 (3 秒)..." -ForegroundColor White
        Start-Sleep -Seconds 3

        # 關閉 handle
        Write-Host "  [動作] 關閉實例檢查 handle..." -ForegroundColor White
        if (-not (Close-D2RHandles)) {
            Write-Host "  [警告] 無法關閉 handles" -ForegroundColor Yellow
            Write-Log "無法關閉 handles" "WARNING"
        }

        # 等待後續啟動
        Write-Host "  [等待] 準備啟動下一個實例 (3 秒)..." -ForegroundColor White
        Write-Host "================================================" -ForegroundColor Cyan
        Start-Sleep -Seconds 3
    }
    catch {
        Write-Host "  [錯誤] 啟動失敗: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "啟動 D2R 時發生錯誤: $_" "ERROR"
    }
}

# ==========================================
# 主程式
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
    Write-Host "  [C] 只關閉 Handles (不啟動遊戲)" -ForegroundColor Magenta
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
            Write-Host "開始批次啟動所有帳號..." -ForegroundColor Green
            foreach ($Account in $Accounts) {
                Start-D2R -Username $Account.Username -Password $Account.Password -DisplayName $Account.DisplayName -Server $Account.Server -LaunchArgs $Account.LaunchArgs
            }
            Write-Host ""
            Write-Host "所有帳號已啟動完成！" -ForegroundColor Green
            Read-Host "按 Enter 返回選單"
        }
        "C" {
            Write-Host ""
            Write-Host "執行 Handle 關閉作業..." -ForegroundColor Magenta
            Close-D2RHandles
            Write-Host ""
            Read-Host "按 Enter 返回選單"
        }
        "Q" {
            Write-Log "退出程式"
            exit 0
        }
        default {
            if ($Choice -match '^\d+$' -and [int]$Choice -ge 1 -and [int]$Choice -le $Accounts.Count) {
                $SelectedAccount = $Accounts[[int]$Choice - 1]
                Start-D2R -Username $SelectedAccount.Username -Password $SelectedAccount.Password -DisplayName $SelectedAccount.DisplayName -Server $SelectedAccount.Server -LaunchArgs $SelectedAccount.LaunchArgs
                Write-Host ""
                Read-Host "按 Enter 返回選單"
            } else {
                Write-Host ""
                Write-Host "無效的選項！請重新選擇。" -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
} while ($true)
