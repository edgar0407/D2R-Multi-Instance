# 更新日誌 (Changelog)

所有版本的重要變更都會記錄在此檔案中。

格式基於 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.0.0/)。

---

## [b0.9.1] - 2025-10-22 (Latest)

### 新增 (Added)
- ✨ **群組功能**：可自訂帳號群組，一鍵啟動特定組合
  - 在 config.ini 中使用 `[Group1]`, `[Group2]` 等格式設定
  - 選單中顯示群組選項 `[G1]`, `[G2]` 等
  - 支援任意帳號組合 (例如: 1,3,5)
- ✨ **DefaultServer 功能**：Server 改為選填，留空自動使用預設伺服器
- ✨ **DefaultLaunchArgs 功能**：LaunchArgs 改為選填，留空自動使用預設參數
- ✨ **參數化等待時間**：新增 `WindowInitDelay` 設定，可自訂視窗初始化等待秒數
- ✨ **版本號顯示**：選單中顯示程式版本 (Version: b0.9.1)
- ✨ **選單顯示伺服器**：帳號列表格式改為 `[編號] 伺服器 - 顯示名稱`
- ✨ **權限狀態顯示**：選單中顯示當前管理員權限狀態
- ✨ **BAT 啟動器**：新增 `D2R_Launcher.bat` 整合自動解除封鎖功能
- ✨ **錯誤處理改善**：PS1 腳本加入全域錯誤捕獲機制 (trap)

### 變更 (Changed)
- 🔄 **啟動流程優化**：改為先關閉 handle 再啟動遊戲，提升效率
  - 舊版：啟動 → 等3秒 → 關handle → 等3秒 (共6秒)
  - 新版：關handle → 啟動 → 等3秒 (共3秒)
- 🔄 **帳號驗證調整**：Server 從必填改為選填
  - 必填欄位：Username, Password
  - 選填欄位：Server, DisplayName, LaunchArgs
- 🔄 **BAT 錯誤訊息改善**：提權失敗時的訊息更友善

### 修復 (Fixed)
- 🐛 修正 PS1 右鍵執行時閃退問題
- 🐛 修正 `param()` 必須在腳本最前面的語法錯誤
- 🐛 修正提權過程的錯誤處理
- 🐛 改善除錯模式的輸出資訊

### 文件 (Documentation)
- 📝 更新 README.md 說明新功能
- 📝 新增 CHANGELOG.md 版本記錄
- 📝 更新 config.ini.sample 範本

---

## [b0.9.0] - 2025-10-18

### 新增 (Added)
- ✨ **自動提權功能**：腳本自動檢測並請求管理員權限
- ✨ **外部設定檔系統**：將所有設定分離到 `config.ini`
- ✨ **INI 檔案解析器**：實作完整的 INI 格式讀取功能
- ✨ **支援相對路徑**：Handle.exe 可使用相對路徑，方便移植
- ✨ **除錯模式**：新增 `-Debug` 參數，敏感資訊僅在除錯模式下顯示
- ✨ **動態帳號載入**：支援多帳號動態載入，使用數字排序
- ✨ **帳號驗證**：Username、Password、Server 為必填，DisplayName 留空則使用帳號

### 變更 (Changed)
- 🔄 改進設定檔結構，分為三大區塊並提供詳細說明
- 🔄 優化錯誤處理與使用者提示訊息
- 🔄 選單會顯示無效帳號警告
- 🔄 [A] 選項自動跳過無效帳號

---

## [Initial Release] - 2025-10-17

### 新增 (Added)
- ✨ 完成多開功能與自動登入
- ✨ 整合 handle 關閉機制
- ✨ 新增視窗標題自訂功能（顯示「D2R: 編號 - 帳號名稱」）
- ✨ 使用 Mutex 避免日誌衝突
- ✨ 轉換為 UTF-8 with BOM 編碼（支援 PowerShell 中文顯示）

### 變更 (Changed)
- 🔄 優化時序避免啟動失敗

---

## 圖例說明

- ✨ 新增功能 (Added)
- 🔄 變更/改善 (Changed)
- 🐛 錯誤修復 (Fixed)
- ⚠️ 即將移除 (Deprecated)
- 🗑️ 已移除 (Removed)
- 🔒 安全性修復 (Security)
- 📝 文件更新 (Documentation)
