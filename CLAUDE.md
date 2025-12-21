# CLAUDE.md - 專案開發文件

> **本文件專為 AI 助手與開發者設計**，包含詳細的技術實作細節、程式架構與開發指南。
> 一般使用者請參閱 [README.md](./README.md) | 版本歷程請參閱 [CHANGELOG.md](./CHANGELOG.md)

---

## 📋 專案概述

**專案名稱**: D2R Multi-Instance Launcher (D2R 多開啟動器)
**當前版本**: v1.0.0
**最後更新**: 2025-12-21
**開發語言**: PowerShell 5.0+
**目標平台**: Windows (繁體中文環境)

### 專案目的

這是一個用於 **Diablo II: Resurrected (暗黑破壞神 II：獄火重生)** 的多開工具，主要功能包括：

1. **繞過遊戲的多開限制**：使用 Sysinternals Handle 工具關閉遊戲的實例檢查機制
2. **自動登入多個帳號**：透過命令列參數自動填入帳號密碼
3. **帳號管理與群組功能**：支援多帳號管理、群組啟動
4. **視窗識別**：為每個遊戲視窗設定自訂標題（D2R: 編號 - 顯示名稱）

---

## 🏗️ 專案架構

### 核心檔案結構

```
D2R-Multi-Instance/
├── D2R_Launcher.ps1           # 主程式（PowerShell 腳本）
├── D2R_Launcher.bat           # BAT 啟動器（推薦使用）
├── D2R_Launcher_Debug.bat     # 除錯模式啟動器
├── config.ini                 # 使用者設定檔（不應上傳至 Git）
├── config.ini.sample          # 設定檔範本
├── README.md                  # 使用者說明文件
├── CHANGELOG.md               # 版本更新記錄
├── CLAUDE.md                  # 本文件（AI/開發者導覽）
├── Handle/
│   ├── handle64.exe          # Sysinternals Handle 工具
│   └── handles_temp.txt      # 臨時輸出檔案
├── logs/
│   └── D2R_Launch_*.log      # 每日日誌檔案
└── images/                    # 截圖資料夾
    ├── Start.jpg
    ├── Menu.jpg
    └── Result.jpg
```

### 主要元件說明

#### 1. **D2R_Launcher.ps1** (主程式腳本)

**編碼**: UTF-8 with BOM
**行數**: 約 800+ 行

**主要功能模組**：

- **自動提權模組** (行 47-89)
  - 檢測當前是否具備管理員權限
  - 若無權限，自動以管理員身分重新啟動腳本
  - 保留 `-Debug` 參數

- **設定檔讀取模組** (行 96-200+)
  - 解析 INI 格式設定檔
  - 支援 `[Paths]`, `[General]`, `[Account1-N]`, `[Group1-N]` 區塊
  - 驗證必填欄位 (Username, Password)
  - 選填欄位支援預設值 (Server, LaunchArgs, DisplayName)

- **日誌系統** (使用 Mutex 避免多進程衝突)
  - 日誌路徑: `logs/D2R_Launch_YYYYMMDD.log`
  - 不記錄敏感資訊 (帳號密碼)
  - 支援除錯模式

- **Handle 管理模組**
  - 使用 `handle64.exe` 掃描 "Check For Other Instances" handle
  - 解析輸出找到進程 ID (PID) 和 Handle ID (HID)
  - 使用 `handle64.exe -c <HID> -p <PID>` 關閉 handle

- **遊戲啟動模組**
  - 組合啟動參數 (`-username`, `-password`, `-address`, `-mod`, 等)
  - 支援自訂啟動參數 (LaunchArgs)
  - 先關閉 handle 再啟動 (優化流程，提升效率 50%)

- **視窗標題設定模組**
  - 使用 Windows API (`user32.dll`)
  - `EnumWindows` 列舉所有視窗
  - `SetWindowText` 設定自訂標題
  - 格式: "D2R: 編號 - 顯示名稱"

- **互動式選單**
  - 顯示系統狀態、權限、版本號
  - 帳號列表 `[1-N] 伺服器 - 顯示名稱`
  - 群組列表 `[G1-GN] 群組名稱 (#帳號編號)`
  - 選項: [A] 全部啟動, [C] 只關閉 Handles, [Q] 退出

#### 2. **D2R_Launcher.bat** (BAT 啟動器)

**編碼**: ASCII (純英文，避免編碼問題)
**用途**:
- 自動檢查並解除從 GitHub 下載的檔案封鎖 (Zone.Identifier)
- 啟動 PowerShell 腳本
- 避免右鍵執行 PS1 時的閃退問題
- 提供友善的錯誤訊息

**流程**:
1. 檢查檔案是否被 Windows 封鎖
2. 若被封鎖，使用 `Unblock-File` 解除
3. 以 `-ExecutionPolicy Bypass` 啟動 PowerShell 腳本
4. 錯誤處理（僅在真正錯誤時暫停）

#### 3. **config.ini** (設定檔)

**編碼**: UTF-8
**格式**: INI 格式

**區塊說明**:

```ini
[Paths]
HandleExePath=Handle\handle64.exe  # 相對或絕對路徑
TempFilePath=Handle\handles_temp.txt
D2RGamePath=D:\Diablo II Resurrected\D2R.exe

[General]
DefaultServer=kr                    # 預設伺服器 (us/eu/kr)
DefaultLaunchArgs=-mod YourMod -txt -w  # 預設啟動參數
WindowInitDelay=3                   # 視窗初始化等待時間（秒）
MenuReturnDelay=5                   # 操作完成後自動返回選單的倒數秒數
LogRetentionDays=30                 # 日誌保留天數（超過自動刪除）

[Account1]
Username=email@example.com          # 必填
Password=password                   # 必填
DisplayName=暱稱                    # 選填（留空使用 Username）
Server=kr                           # 選填（留空使用 DefaultServer）
LaunchArgs=-mod YourMod -txt -w     # 選填（留空使用 DefaultLaunchArgs）

[Group1]
DisplayName=全部帳號               # 群組顯示名稱
Accounts=1,2,3                     # 要啟動的帳號編號（逗號分隔）
```

---

## 🔧 技術細節

### 核心技術原理

#### 1. **多開繞過機制**

D2R 遊戲使用名為 **"Check For Other Instances"** 的 Windows Handle 來偵測是否已有其他實例在運行。

**繞過步驟**:
1. 使用 `handle64.exe "Check For Other Instances"` 掃描該 handle
2. 解析輸出（格式: `D2R.exe pid: <PID> type: Event <HID>: Check For Other Instances`）
3. 使用正規表示式 `tokens=3,6` 取得 PID 和 HID
4. 執行 `handle64.exe -c <HID> -p <PID> -y` 關閉 handle
5. 遊戲無法偵測到其他實例，允許多開

**版本 b0.9.1 優化**:
- 舊版: 啟動遊戲 → 等待 3 秒 → 關閉 handle → 再等 3 秒 (總計 6 秒)
- 新版: **先關閉 handle** → 啟動遊戲 → 等待 3 秒 (總計 3 秒)
- 效率提升約 **50%**

#### 2. **自動登入機制**

使用 D2R 官方支援的命令列參數:
```powershell
D2R.exe -username <email> -password <password> -address <server>.actual.battle.net
```

**支援的參數**:
- `-username <email>`: 自動填入帳號
- `-password <password>`: 自動填入密碼
- `-address <server>`: 伺服器（us/eu/kr.actual.battle.net）
- `-mod <modname>`: 載入 MOD
- `-txt`: txt 檔讀取模式
- `-w`: 視窗模式
- `-ns`: 靜音

#### 3. **視窗標題設定 (Windows API)**

使用 PowerShell 呼叫 Windows API:

```powershell
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool SetWindowText(IntPtr hWnd, string lpString);

    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
}
"@
```

**流程**:
1. 啟動遊戲前記錄現有的 D2R 視窗
2. 啟動遊戲後使用 `EnumWindows` 列舉所有視窗
3. 比對找出新視窗
4. 使用 `SetWindowText` 設定標題為 "D2R: 編號 - 顯示名稱"

#### 4. **日誌系統 (Mutex 避免衝突 + Email 遮罩)**

當同時啟動多個實例時，多個進程可能同時寫入日誌檔案，造成衝突。

**Mutex 解決方案**:
```powershell
$Mutex = New-Object System.Threading.Mutex($false, "Global\D2RLauncherLogMutex")
try {
    $Mutex.WaitOne() | Out-Null
    # 寫入日誌
    Add-Content -Path $LogFile -Value $Message -Encoding UTF8
}
finally {
    $Mutex.ReleaseMutex()
}
```

**Email 遮罩功能 (v0.9.2+)**:

為保護隱私，日誌中的 email 帳號會自動遮罩：

```powershell
function Mask-Email {
    param([string]$Text)
    # 格式：example@domain.com → e***@domain.com
    $MaskedText = $Text -replace '([a-zA-Z0-9._%+-]+)@([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})', {
        param($Match)
        $LocalPart = $Match.Groups[1].Value
        $Domain = $Match.Groups[2].Value
        $FirstChar = $LocalPart.Substring(0, 1)
        return "$FirstChar***@$Domain"
    }
    return $MaskedText
}
```

**範例**:
- `test@example.com` → `t***@example.com`
- `myemail@gmail.com` → `m***@gmail.com`

---

## 🛠️ 開發注意事項

### 檔案編碼規範

| 檔案類型 | 編碼格式 | 原因 |
|---------|---------|------|
| `.ps1` | UTF-8 with BOM | PowerShell 需要 BOM 才能正確顯示中文 |
| `.ini` | UTF-8 (無 BOM) | 設定檔通用格式 |
| `.bat` | ASCII (純英文) | 避免編碼問題，中文訊息由 PS1 處理 |
| `.md` | UTF-8 | Markdown 標準編碼 |

### 安全性考量

⚠️ **重要警告**:
- `config.ini` 中的帳號密碼以**明文**儲存
- 此檔案不應上傳至公開的版本控制系統
- `.gitignore` 已包含 `config.ini`
- 僅供個人學習測試使用

### 版本控制策略

**主要分支**:
- `main`: 主分支（穩定版本）
- `master`: 開發分支

**提交規範**:
```
<type>: <description>

<body>

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Type 類型**:
- `feat`: 新功能
- `fix`: 錯誤修復
- `docs`: 文件更新
- `chore`: 雜項（不影響功能的變更）
- `refactor`: 重構

---

## 🚀 版本歷史重點

### v1.0.0 (2025-12-21) - 當前版本 🎉 正式版

**主要新增**:
- ✨ 程式啟動時記錄完整環境資訊（版本、權限、路徑、設定）
- ✨ 程式結束時記錄結束狀態
- ✨ 日誌記錄 PowerShell 版本與作業系統資訊
- ✨ 操作完成後自動倒數返回選單（MenuReturnDelay 參數）
- ✨ 倒數期間可按任意鍵立即返回
- ✨ 自動清理過期日誌檔案（LogRetentionDays 參數，預設 30 天）

**主要修復**:
- 🐛 日誌檔案編碼問題（中文顯示亂碼）
- 🐛 D2R_Launcher.bat 中文編碼問題
- 🐛 D2R_Launcher.bat 版本號與主程式不同步

**技術改進**:
- 日誌系統使用 `[System.IO.File]::AppendAllText()` 搭配 UTF-8 編碼
- BAT 檔案改用純英文避免編碼問題
- 新增 `Wait-AndReturn` 函數處理倒數返回邏輯

### b0.9.4 (2025-10-29)

**主要新增**:
- ✨ 每個帳號可設定獨立的 D2RGamePath（支援不同遊戲版本多開）
- ✨ DefaultD2RGamePath 設定（在 [General] 區塊設定預設遊戲路徑）

**主要改進**:
- 🔄 將遊戲路徑驗證從初始化階段移至啟動時個別檢查
- 🔄 向後相容：若未設定 DefaultD2RGamePath，自動讀取 Paths.D2RGamePath
- 📝 config.ini.sample 簡化範例（最簡單與全客制參數兩種）

**技術細節**:
- 每個 Account 物件新增 D2RGamePath 欄位
- Start-D2R 函數新增 D2RGamePath 參數驗證
- 帳號載入時支援 D2RGamePath 選填（留空使用 DefaultD2RGamePath）

### b0.9.3 (2025-10-25)

**主要修復**:
- 🐛 修正 UAC 提權機制缺陷（即使「以管理員身分執行」也可能只有 Filtered Admin Token，權限不足以關閉 handle）
- 🐛 強制使用 Start-Process -Verb RunAs 重新啟動，確保獲得 Full Admin Token

**主要新增**:
- ✨ AlreadyElevated 內部參數（避免無限循環提權）

**技術改進**:
- 所有執行路徑都必須通過 `Start-Process -Verb RunAs` 重新啟動
- 解決 Windows 10 環境下「右鍵以管理員身分執行」權限不足的問題
- 確保獲得完整的管理員權限，成功關閉 D2R handle

### b0.9.2 (2025-10-24)

**主要修復**:
- 🐛 修正 Handle ID 解析錯誤（正則表達式誤匹配路徑中的字符）
- 🐛 修正 Tokens 解析邏輯（強化結構驗證）
- 🐛 解決部分使用者環境下無法關閉 handle 的問題

**主要新增**:
- ✨ Email 遮罩功能（日誌中自動遮蔽 email 帳號）
- ✨ 詳細的解析診斷日誌（記錄每一行的解析過程）
- ✨ Handle.exe 原始輸出記錄到日誌（方便診斷問題）
- ✨ 雙重解析機制（正則表達式 + Tokens，提升相容性）

**技術改進**:
- 改進正則表達式：`'^D2R\.exe\s+pid:\s*(\d+)\s+type:\s+\w+\s+([0-9A-Fa-f]+):'`
- 新增 Tokens 驗證：檢查 Token[0], Token[1], Token[3] 的值
- 過濾干擾行：只處理包含 D2R.exe 的行

### b0.9.1 (2025-10-22)

**主要新增**:
- ✨ 群組功能（自訂帳號組合）
- ✨ DefaultServer/DefaultLaunchArgs（選填欄位）
- ✨ 參數化等待時間 (WindowInitDelay)
- ✨ 選單改善（版本號、伺服器、權限狀態）
- ✨ BAT 啟動器整合自動解除封鎖

**主要優化**:
- 🔄 啟動流程優化（先關 handle 再啟動，效率提升 50%）
- 🔄 Server 從必填改為選填

**主要修復**:
- 🐛 修正 PS1 右鍵執行閃退問題
- 🐛 修正語法錯誤和提權處理

### b0.9.0 (2025-10-18)

**主要新增**:
- ✨ 自動提權功能
- ✨ 外部設定檔系統 (config.ini)
- ✨ 除錯模式 (-Debug)
- ✨ 動態帳號載入

### Initial Release (2025-10-17)

**主要新增**:
- ✨ 多開功能與自動登入
- ✨ Handle 關閉機制
- ✨ 視窗標題自訂
- ✨ 日誌系統 (Mutex)

---

## 📚 相關資源

### 外部工具

- **Sysinternals Handle**: https://learn.microsoft.com/en-us/sysinternals/downloads/handle
  - 用途: 檢視和關閉 Windows Handles
  - 版本: handle64.exe (64-bit)

### 技術文件

- **PowerShell Add-Type**: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/add-type
- **Windows API (user32.dll)**: https://learn.microsoft.com/en-us/windows/win32/api/winuser/
- **INI 檔案格式**: https://en.wikipedia.org/wiki/INI_file

---

## 🤝 給開發者的建議

### 如果你是 Claude AI 助手

1. **理解專案目的**: 這是一個遊戲多開工具，主要用於個人學習測試
2. **注意安全性**: 不應建議任何可能違反遊戲服務條款的功能
3. **遵循編碼規範**: 注意不同檔案的編碼格式
4. **測試建議**: 建議使用者在本地測試，不要直接修改生產設定

### 如果你是人類開發者

1. **環境需求**:
   - Windows 10/11 (繁體中文環境)
   - PowerShell 5.0+
   - 管理員權限

2. **開發工具建議**:
   - Visual Studio Code + PowerShell Extension
   - 確保編輯器支援 UTF-8 with BOM

3. **測試流程**:
   - 先備份 `config.ini`
   - 使用 `D2R_Launcher_Debug.bat` 測試
   - 檢查日誌檔案 (`logs/`)

4. **貢獻建議**:
   - Fork 專案並建立 feature branch
   - 遵循 commit message 規範
   - 更新 CHANGELOG.md

---

## 📞 聯絡資訊

**GitHub Repository**: https://github.com/edgar0407/D2R-Multi-Instance
**Issues**: https://github.com/edgar0407/D2R-Multi-Instance/issues

---

**文件最後更新**: 2025-12-21
**文件版本**: 1.4
**對應專案版本**: v1.0.0
