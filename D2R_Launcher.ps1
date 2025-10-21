# ==========================================
# D2R 多開啟動器
# 版本: b0.9.1
# ==========================================

# 檢查啟動參數（必須在第一行）
param(
    [switch]$Debug  # 使用 -debug 參數啟動可顯示除錯資訊
)

# 版本資訊
$script:Version = "b0.9.1"

# 設定全域除錯模式
$script:DebugMode = $Debug

# 設定錯誤處理 - 發生錯誤時不要立即終止
$ErrorActionPreference = "Continue"

# 捕獲未處理的錯誤
trap {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  發生嚴重錯誤！" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "錯誤訊息: $_" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "可能的原因:" -ForegroundColor Cyan
    Write-Host "  1. PowerShell 執行策略限制" -ForegroundColor White
    Write-Host "  2. 檔案權限問題" -ForegroundColor White
    Write-Host "  3. 設定檔格式錯誤" -ForegroundColor White
    Write-Host ""
    Write-Host "建議: 請使用 D2R_Launcher_Debug.bat 來啟動除錯模式" -ForegroundColor Green
    Write-Host ""
    Read-Host "按 Enter 鍵退出"
    exit 1
}

# 設定控制台編碼為 UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ==========================================
# 自動提權檢查
# ==========================================
$CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)
$IsAdmin = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host "檢測到需要管理員權限，正在重新啟動..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "即將彈出 UAC 權限提示，請點擊「是」以繼續" -ForegroundColor Cyan
    Write-Host ""

    # 重新以管理員身分啟動，保留 debug 參數
    $ScriptPath = $MyInvocation.MyCommand.Path
    $Arguments = "-ExecutionPolicy Bypass -File `"$ScriptPath`""
    if ($Debug) {
        $Arguments += " -Debug"
    }

    try {
        $Process = Start-Process powershell.exe -Verb RunAs -ArgumentList $Arguments -PassThru -ErrorAction Stop
        # 成功啟動，退出當前進程 (退出代碼 0 = 成功)
        exit 0
    }
    catch {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "  提權失敗！" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "可能的原因:" -ForegroundColor Yellow
        Write-Host "  1. 您點擊了「否」拒絕提權" -ForegroundColor White
        Write-Host "  2. 當前用戶不是管理員群組成員" -ForegroundColor White
        Write-Host "  3. UAC 被系統政策鎖定" -ForegroundColor White
        Write-Host ""
        Write-Host "本程式需要管理員權限來:" -ForegroundColor Cyan
        Write-Host "  - 使用 handle64.exe 查看其他進程的 handles" -ForegroundColor White
        Write-Host "  - 關閉 D2R 的多開檢查機制" -ForegroundColor White
        Write-Host ""
        Write-Host "請聯繫系統管理員或使用管理員帳戶執行此程式" -ForegroundColor Yellow
        Write-Host ""
        Read-Host "按 Enter 鍵退出"
        exit 1
    }
}

Write-Host "✓ 已確認管理員權限" -ForegroundColor Green
if ($script:DebugMode) {
    Write-Host "✓ 除錯模式已啟用" -ForegroundColor Magenta
}

# ==========================================
# 讀取設定檔
# ==========================================
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir "config.ini"

if (-not (Test-Path $ConfigPath)) {
    Write-Host "錯誤: 找不到設定檔 config.ini" -ForegroundColor Red
    Write-Host "請確認 $ConfigPath 存在" -ForegroundColor Red
    Write-Host ""
    Read-Host "按 Enter 鍵退出"
    exit 1
}

Write-Host "✓ 正在讀取設定檔..." -ForegroundColor Green

# 讀取 INI 檔案的函數
function Read-IniFile {
    param([string]$FilePath)

    $Ini = @{}
    $CurrentSection = ""

    Get-Content $FilePath -Encoding UTF8 | ForEach-Object {
        $Line = $_.Trim()

        # 忽略註解和空行
        if ($Line -match '^\s*#' -or $Line -match '^\s*$') {
            return
        }

        # 解析區段 [Section]
        if ($Line -match '^\[(.+)\]$') {
            $CurrentSection = $Matches[1]
            $Ini[$CurrentSection] = @{}
            return
        }

        # 解析鍵值對 Key=Value
        if ($Line -match '^(.+?)\s*=\s*(.*)$') {
            $Key = $Matches[1].Trim()
            $Value = $Matches[2].Trim()

            if ($CurrentSection) {
                $Ini[$CurrentSection][$Key] = $Value
            }
        }
    }

    return $Ini
}

$Config = Read-IniFile -FilePath $ConfigPath

# ==========================================
# 載入路徑設定
# ==========================================
$HandleExePath = $Config["Paths"]["HandleExePath"]
$TempFilePath = $Config["Paths"]["TempFilePath"]
$D2RGamePath = $Config["Paths"]["D2RGamePath"]

# 驗證必要的路徑設定
if ([string]::IsNullOrWhiteSpace($HandleExePath)) {
    Write-Host "錯誤: config.ini 中未設定 HandleExePath" -ForegroundColor Red
    Write-Host ""
    Read-Host "按 Enter 鍵退出"
    exit 1
}
if ([string]::IsNullOrWhiteSpace($D2RGamePath)) {
    Write-Host "錯誤: config.ini 中未設定 D2RGamePath" -ForegroundColor Red
    Write-Host ""
    Read-Host "按 Enter 鍵退出"
    exit 1
}

# 去除路徑前後的空白和引號
$HandleExePath = $HandleExePath.Trim().Trim('"').Trim("'")
$TempFilePath = if ($TempFilePath) { $TempFilePath.Trim().Trim('"').Trim("'") } else { "Handle\handles_temp.txt" }
$D2RGamePath = $D2RGamePath.Trim().Trim('"').Trim("'")

# 處理相對路徑
if (-not [System.IO.Path]::IsPathRooted($HandleExePath)) {
    $HandleExePath = Join-Path $ScriptDir $HandleExePath
}
if (-not [System.IO.Path]::IsPathRooted($TempFilePath)) {
    $TempFilePath = Join-Path $ScriptDir $TempFilePath
}

# 確保 TempFilePath 的目錄存在
$TempFileDir = Split-Path -Parent $TempFilePath
if ($TempFileDir -and -not (Test-Path $TempFileDir)) {
    New-Item -ItemType Directory -Path $TempFileDir -Force | Out-Null
}

# 日誌路徑
$LogDir = Join-Path $ScriptDir "logs"

# ==========================================
# 載入一般設定
# ==========================================
$DefaultServer = $Config["General"]["DefaultServer"]
$DefaultLaunchArgs = $Config["General"]["DefaultLaunchArgs"]
$WindowInitDelay = $Config["General"]["WindowInitDelay"]

# 設定預設值
if ([string]::IsNullOrWhiteSpace($WindowInitDelay) -or -not ($WindowInitDelay -match '^\d+$')) {
    $WindowInitDelay = 3  # 預設 3 秒
} else {
    $WindowInitDelay = [int]$WindowInitDelay
}

# ==========================================
# 載入帳號設定
# ==========================================
$Accounts = @()
$AccountSections = $Config.Keys | Where-Object { $_ -match '^Account\d+$' } | Sort-Object {
    # 數字排序：Account1, Account2, ..., Account10
    [int]($_ -replace 'Account', '')
}

$LoadErrors = @()
$InvalidAccounts = @()  # 記錄無效帳號的索引

foreach ($Section in $AccountSections) {
    $Username = $Config[$Section]["Username"]
    $Password = $Config[$Section]["Password"]
    $DisplayName = $Config[$Section]["DisplayName"]
    $Server = $Config[$Section]["Server"]
    $LaunchArgs = $Config[$Section]["LaunchArgs"]

    # 驗證必要欄位：Username, Password (Server 改為選填)
    $MissingFields = @()
    if ([string]::IsNullOrWhiteSpace($Username)) { $MissingFields += "Username" }
    if ([string]::IsNullOrWhiteSpace($Password)) { $MissingFields += "Password" }

    if ($MissingFields.Count -gt 0) {
        $ErrorMsg = "[$Section] 缺少必要欄位: $($MissingFields -join ', ')"
        $LoadErrors += $ErrorMsg

        # 記錄無效帳號的編號（用於選單顯示）
        $AccountNumber = [int]($Section -replace 'Account', '')
        $InvalidAccounts += $AccountNumber

        Write-Host "  ⚠ $ErrorMsg" -ForegroundColor Yellow
        continue
    }

    # DisplayName 留空則使用 Username
    if ([string]::IsNullOrWhiteSpace($DisplayName)) {
        $DisplayName = $Username
    }

    # Server 留空則使用 DefaultServer
    if ([string]::IsNullOrWhiteSpace($Server)) {
        $Server = $DefaultServer
    }

    # LaunchArgs 留空則使用 DefaultLaunchArgs
    if ([string]::IsNullOrWhiteSpace($LaunchArgs)) {
        $LaunchArgs = $DefaultLaunchArgs
    }

    # 建立帳號物件
    $Account = @{
        Username = $Username.Trim()
        Password = $Password.Trim()
        DisplayName = $DisplayName.Trim()
        Server = if ($Server) { $Server.Trim() } else { "" }
        LaunchArgs = if ($LaunchArgs) { $LaunchArgs.Trim() } else { "" }
        IsValid = $true
    }
    $Accounts += $Account
}

# 將無效帳號資訊存為全域變數供選單使用
$script:InvalidAccounts = $InvalidAccounts

# ==========================================
# 載入群組設定
# ==========================================
$Groups = @()
$GroupSections = $Config.Keys | Where-Object { $_ -match '^Group\d+$' } | Sort-Object {
    # 數字排序：Group1, Group2, ..., Group10
    [int]($_ -replace 'Group', '')
}

foreach ($Section in $GroupSections) {
    $GroupDisplayName = $Config[$Section]["DisplayName"]
    $GroupAccounts = $Config[$Section]["Accounts"]

    # 跳過沒有設定的群組
    if ([string]::IsNullOrWhiteSpace($GroupDisplayName) -or [string]::IsNullOrWhiteSpace($GroupAccounts)) {
        continue
    }

    # 解析帳號編號列表 (例如: "1,3,5" -> [1, 3, 5])
    $AccountIndices = @()
    $GroupAccounts.Split(',') | ForEach-Object {
        $Num = $_.Trim()
        if ($Num -match '^\d+$') {
            $Index = [int]$Num
            # 驗證帳號編號是否存在
            if ($Index -ge 1 -and $Index -le $Accounts.Count) {
                $AccountIndices += $Index
            }
        }
    }

    # 如果群組沒有有效帳號,跳過
    if ($AccountIndices.Count -eq 0) {
        continue
    }

    # 建立群組物件
    $Group = @{
        DisplayName = $GroupDisplayName.Trim()
        AccountIndices = $AccountIndices
    }
    $Groups += $Group
}

# 顯示載入結果
if ($Accounts.Count -eq 0) {
    Write-Host ""
    Write-Host "錯誤: 未載入任何有效帳號！" -ForegroundColor Red
    if ($LoadErrors.Count -gt 0) {
        Write-Host "發現以下問題:" -ForegroundColor Red
        $LoadErrors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    }
    Write-Host ""
    Write-Host "請檢查 config.ini 中的帳號設定" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "按 Enter 鍵退出"
    exit 1
} else {
    Write-Host "✓ 成功載入 $($Accounts.Count) 個帳號" -ForegroundColor Green
    if ($LoadErrors.Count -gt 0) {
        Write-Host "  (有 $($LoadErrors.Count) 個帳號因設定不完整而被跳過)" -ForegroundColor Yellow
    }
    if ($Groups.Count -gt 0) {
        Write-Host "✓ 成功載入 $($Groups.Count) 個群組" -ForegroundColor Green
    }
}

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

    # 使用逗號強制返回陣列，避免 PowerShell 自動解包單一元素
    return ,$script:Handles
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
    Write-Host ""
    Read-Host "按 Enter 鍵退出"
    exit 1
}

if (-not (Test-Path $D2RGamePath)) {
    Write-Host "錯誤: 找不到 D2R 遊戲，路徑: $D2RGamePath" -ForegroundColor Red
    Write-Host ""
    Read-Host "按 Enter 鍵退出"
    exit 1
}

# 建立日誌目錄
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

# ==========================================
# 初始化 handle.exe (接受 EULA)
# ==========================================
Write-Host "✓ 正在初始化 handle.exe..." -ForegroundColor Green
try {
    $InitResult = & $HandleExePath -accepteula 2>&1 | Out-Null
    Write-Host "✓ handle.exe 初始化完成" -ForegroundColor Green
} catch {
    Write-Host "警告: handle.exe 初始化時發生錯誤 (可能不影響正常使用)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  初始化完成，準備啟動主選單" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Start-Sleep -Seconds 1

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
        # 加上 -accepteula 避免首次執行時的授權提示
        $HandleOutput = & $HandleExePath -accepteula -a "Check For Other Instances" -nobanner 2>&1

        if ($LASTEXITCODE -ne 0 -and $HandleOutput -notmatch "No matching handles found") {
            Write-Log "警告: handle.exe 執行異常,退出代碼: $LASTEXITCODE" "WARNING"
            if ($script:DebugMode) {
                Write-Host "  [除錯] handle.exe 退出代碼: $LASTEXITCODE" -ForegroundColor DarkGray
                Write-Host "  [除錯] handle.exe 輸出: $HandleOutput" -ForegroundColor DarkGray
            }
        }

        # 儲存輸出到檔案
        $HandleOutput | Out-File -FilePath $TempFilePath -Encoding UTF8

        # 除錯模式顯示 handle.exe 原始輸出
        if ($script:DebugMode) {
            Write-Host "  [除錯] handle.exe 搜尋結果:" -ForegroundColor DarkGray
            $HandleOutput | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        }

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
                    $CloseResult = & $HandleExePath -accepteula -p $ProcessID -c $HandleID -y 2>&1

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

            # 除錯模式顯示可能的原因
            if ($script:DebugMode) {
                Write-Host "  [除錯] 可能原因:" -ForegroundColor Yellow
                Write-Host "    1. 遊戲尚未建立 handle (啟動太快)" -ForegroundColor DarkGray
                Write-Host "    2. 遊戲啟動失敗或已崩潰" -ForegroundColor DarkGray
                Write-Host "    3. Handle 名稱已改變" -ForegroundColor DarkGray
                Write-Host "    4. 權限不足,無法查看進程 handle" -ForegroundColor DarkGray
            }
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
        # 先檢查並關閉 handle (允許新實例啟動)
        Write-Host "  [執行] 檢查並關閉 handle..." -ForegroundColor White
        if (-not (Close-D2RHandles)) {
            Write-Host "  [警告] 無法關閉 handles" -ForegroundColor Yellow
            Write-Log "無法關閉 handles" "WARNING"
        }

        # 在啟動前，記錄現有視窗的 D2R 視窗
        $WindowsBeforeLaunch = Get-D2RWindowHandles
        Write-Host "  [偵測] 啟動前已有 $($WindowsBeforeLaunch.Count) 個 D2R 視窗" -ForegroundColor Gray

        # 構建遊戲啟動參數列表
        $ArgsList = @()
        $ArgsList += "-username"
        $ArgsList += $Username
        $ArgsList += "-password"
        $ArgsList += $Password

        # 除錯模式才顯示敏感資訊
        if ($script:DebugMode) {
            Write-Host "  [除錯] 使用帳號: $Username" -ForegroundColor DarkGray
            Write-Host "  [除錯] 密碼長度: $($Password.Length) 字元" -ForegroundColor DarkGray
            if ($Password.Length -eq 0) {
                Write-Host "  [警告] 密碼為空！" -ForegroundColor Yellow
            }
        }

        # 加入伺服器地址
        if ($Server -and $ServerAddresses.ContainsKey($Server.ToLower())) {
            $ServerAddress = $ServerAddresses[$Server.ToLower()]
            $ArgsList += "-address"
            $ArgsList += $ServerAddress
            Write-Host "  [伺服器] $Server ($ServerAddress)" -ForegroundColor Cyan
            Write-Log "伺服器: $Server ($ServerAddress)" "INFO"
        } else {
            if ($script:DebugMode) {
                Write-Host "  [除錯] 伺服器設定: '$Server' (無效或未設定)" -ForegroundColor DarkGray
            }
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
        Write-Host "  [等待] 遊戲視窗初始化中 ($WindowInitDelay 秒)..." -ForegroundColor White
        Start-Sleep -Seconds $WindowInitDelay

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

        # 啟動完成
        Write-Host "================================================" -ForegroundColor Cyan
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
    Write-Host "       D2R 多開啟動器" -ForegroundColor Cyan
    Write-Host "      (Version: $($script:Version))" -ForegroundColor Gray
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # 顯示系統狀態
    $CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)
    $IsAdmin = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    Write-Host "系統狀態:" -ForegroundColor Cyan
    Write-Host "  權限: " -NoNewline -ForegroundColor White
    if ($IsAdmin) {
        Write-Host "✓ 管理員權限" -ForegroundColor Green
    } else {
        Write-Host "✗ 無管理員權限 (功能可能受限)" -ForegroundColor Red
    }
    if ($script:DebugMode) {
        Write-Host "  模式: " -NoNewline -ForegroundColor White
        Write-Host "除錯模式" -ForegroundColor Magenta
    }

    Write-Host ""
    Write-Host "可用帳號:" -ForegroundColor White
    Write-Host ""

    # 顯示有效帳號
    for ($i = 0; $i -lt $Accounts.Count; $i++) {
        $ServerName = if ($Accounts[$i].Server) { $Accounts[$i].Server.ToUpper() } else { "未設定" }
        Write-Host "  [$($i + 1)] " -NoNewline -ForegroundColor White
        Write-Host "$ServerName" -NoNewline -ForegroundColor Cyan
        Write-Host " - $($Accounts[$i].DisplayName)" -ForegroundColor Yellow
    }

    # 顯示無效帳號警告
    if ($script:InvalidAccounts.Count -gt 0) {
        Write-Host ""
        Write-Host "⚠ 以下帳號資料不完整，已跳過:" -ForegroundColor Red
        foreach ($InvalidNum in $script:InvalidAccounts) {
            Write-Host "  [Account$InvalidNum] 設定不完整（缺少必要欄位）" -ForegroundColor DarkGray
        }
    }

    # 顯示群組
    if ($Groups.Count -gt 0) {
        Write-Host ""
        Write-Host "自訂群組:" -ForegroundColor White
        Write-Host ""
        for ($i = 0; $i -lt $Groups.Count; $i++) {
            $GroupKey = "G$($i + 1)"
            $AccountList = ($Groups[$i].AccountIndices | ForEach-Object { "#$_" }) -join ','
            Write-Host "  [$GroupKey] " -NoNewline -ForegroundColor White
            Write-Host "$($Groups[$i].DisplayName)" -NoNewline -ForegroundColor Green
            Write-Host " ($AccountList)" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Host "  [A] 啟動所有有效帳號" -ForegroundColor Green
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
            if ($Accounts.Count -eq 0) {
                Write-Host "沒有可用的帳號！" -ForegroundColor Red
                Read-Host "按 Enter 返回選單"
                continue
            }

            if ($script:InvalidAccounts.Count -gt 0) {
                Write-Host "注意: 將跳過 $($script:InvalidAccounts.Count) 個設定不完整的帳號" -ForegroundColor Yellow
                Write-Host ""
            }

            Write-Host "開始啟動所有有效帳號..." -ForegroundColor Green
            for ($i = 0; $i -lt $Accounts.Count; $i++) {
                $Account = $Accounts[$i]
                Start-D2R -Username $Account.Username -Password $Account.Password -DisplayName $Account.DisplayName -Server $Account.Server -LaunchArgs $Account.LaunchArgs -AccountNumber ($i + 1)
            }
            Write-Host ""
            Write-Host "所有有效帳號已啟動完畢！" -ForegroundColor Green
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
            # 檢查是否為群組選擇 (G1, G2, G3...)
            if ($Choice -match '^G(\d+)$') {
                $GroupIndex = [int]$Matches[1] - 1
                if ($GroupIndex -ge 0 -and $GroupIndex -lt $Groups.Count) {
                    $SelectedGroup = $Groups[$GroupIndex]
                    Write-Host ""
                    Write-Host "開始啟動群組: $($SelectedGroup.DisplayName)" -ForegroundColor Green
                    Write-Host "包含帳號: $($SelectedGroup.AccountIndices -join ', ')" -ForegroundColor Gray
                    Write-Host ""

                    foreach ($AccNum in $SelectedGroup.AccountIndices) {
                        $AccountIndex = $AccNum - 1
                        if ($AccountIndex -ge 0 -and $AccountIndex -lt $Accounts.Count) {
                            $Account = $Accounts[$AccountIndex]
                            Start-D2R -Username $Account.Username -Password $Account.Password -DisplayName $Account.DisplayName -Server $Account.Server -LaunchArgs $Account.LaunchArgs -AccountNumber $AccNum
                        }
                    }
                    Write-Host ""
                    Write-Host "群組 '$($SelectedGroup.DisplayName)' 已啟動完畢！" -ForegroundColor Green
                    Read-Host "按 Enter 返回選單"
                } else {
                    Write-Host ""
                    Write-Host "無效的群組編號！" -ForegroundColor Red
                    Start-Sleep -Seconds 1
                }
            }
            # 檢查是否為帳號選擇 (1, 2, 3...)
            elseif ($Choice -match '^\d+$' -and [int]$Choice -ge 1 -and [int]$Choice -le $Accounts.Count) {
                $AccountIndex = [int]$Choice - 1
                $SelectedAccount = $Accounts[$AccountIndex]
                Start-D2R -Username $SelectedAccount.Username -Password $SelectedAccount.Password -DisplayName $SelectedAccount.DisplayName -Server $SelectedAccount.Server -LaunchArgs $SelectedAccount.LaunchArgs -AccountNumber ([int]$Choice)
                Write-Host ""
                Read-Host "按 Enter 返回選單"
            }
            # 無效選擇
            else {
                Write-Host ""
                Write-Host "無效選擇！請重新輸入" -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
} while ($true)
