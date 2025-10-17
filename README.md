# D2R 多開工具

使用 handle.exe 繞過 D2R 的多開檢查機制，實現同時運行多個遊戲實例並自動登入。

## 快速開始

### 1. 下載必要工具
- 前往 [Sysinternals Handle 下載頁面](https://learn.microsoft.com/en-us/sysinternals/downloads/handle)
- 下載 Handle.zip 並解壓縮
- 將 `handle64.exe` 放到指定路徑（例如 `D:\D2R多開\Handle\handle64.exe`）

### 2. 設定腳本
編輯 `D2R_Launcher.ps1` 開頭的設定：

```powershell
# 步驟 1: 帳號設定
$Accounts = @(
    @{
        Username = "your_email@example.com"
        Password = "your_password"
        DisplayName = "帳號暱稱"
        Server = "kr"  # us/eu/kr
        LaunchArgs = "-mod YourMod -txt -w"
    }
)

# 步驟 2: 路徑設定
$HandleExePath = "E:\LocatTools\Handle\handle64.exe"
$D2RGamePath = "E:\Diablo II Resurrected\D2R.exe"
```

### 3. 執行
右鍵點擊 `D2R多開_右鍵管理選執行.bat`，選擇「**以系統管理員身分執行**」

## 功能特色

- ✅ **自動登入**：遊戲啟動後自動填入帳號密碼
- ✅ **多開支援**：自動關閉實例檢查，可同時運行多個帳號
- ✅ **互動式選單**：選擇單一帳號或啟動全部
- ✅ **伺服器選擇**：支援 US/EU/KR 伺服器
- ✅ **MOD 支援**：可自訂 MOD 和啟動參數
- ✅ **日誌記錄**：記錄操作但不記錄敏感資訊

## 使用說明

### 選單選項
- **[1-2]** - 啟動指定帳號
- **[A]** - 啟動所有帳號
- **[C]** - 只關閉 Handles（不啟動遊戲）
- **[Q]** - 退出

### 運作流程
1. 啟動遊戲並自動登入
2. 等待 3 秒讓遊戲初始化
3. 關閉實例檢查 handle
4. 等待 3 秒後可啟動下一個實例

## 技術原理

### Handle 關閉機制
D2R 使用名為 "Check For Other Instances" 的 handle 來檢測其他實例。本工具：
1. 使用 handle64.exe 掃描該 handle
2. 使用 tokens=3,6 方法解析進程 ID 和 handle ID
3. 關閉該 handle 以允許多開

**關鍵**：必須在遊戲啟動後才關閉 handle（因為 handle 是遊戲啟動時才建立的）

### 支援的啟動參數
- `-username <email>` - 自動填入帳號
- `-password <password>` - 自動填入密碼
- `-address <server>` - 指定伺服器（us/eu/kr.actual.battle.net）
- `-mod <modname>` - 載入 MOD
- `-txt` - txt 檔讀取模式
- `-w` - 視窗模式
- `-ns` - 靜音

## 注意事項

### 安全性
- ⚠️ 帳號密碼以明文儲存在腳本中，請妥善保管
- 日誌不記錄敏感資訊
- 僅供個人學習測試，請遵守遊戲服務條款

### 系統需求
- Windows 系統（繁體中文環境）
- PowerShell 5.0 以上
- **必須以管理員權限執行**

### 檔案編碼
- 所有檔案使用 ANSI (Big5) 編碼
- 如需修改，請確保編輯器使用 Big5 編碼儲存

## 檔案結構

```
D2R多開/
├── D2R_Launcher.ps1                  # 主程式（包含所有設定）
├── D2R多開_右鍵管理選執行.bat          # 啟動器
├── logs/                             # 日誌目錄（自動建立）
└── README.md                         # 說明文件
```

## 更新日誌

**2025-10-17**
- 完成多開功能與自動登入
- 整合 handle 關閉機制
- 所有設定集中在單一檔案
- 優化時序避免啟動失敗
- 使用 Mutex 避免日誌衝突
- 轉換為 ANSI (Big5) 編碼
