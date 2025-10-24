# 更新日誌 (Changelog)

> **版本歷程記錄**：供開發者與使用者快速了解各版本的更新內容
> 使用說明請參閱 [README.md](./README.md) | 技術細節請參閱 [CLAUDE.md](./CLAUDE.md)

---

## [b0.9.2] - 2025-10-24

修正 handle 解析錯誤，解決部分使用者環境下無法正確關閉 handle 的問題。

Fix - Handle ID 解析錯誤（正則表達式誤匹配路徑中的字符，導致解析出錯誤的 Handle ID）
Fix - Tokens 解析邏輯不夠嚴格，未驗證關鍵欄位結構
Add - 詳細的解析診斷日誌功能（記錄每一行的解析過程）
Add - Handle.exe 原始輸出記錄到日誌檔案（方便使用者回報問題）

---

## [b0.9.1] - 2025-10-22

新增群組功能，優化啟動流程效率提升 50%。

Add - 群組功能（自訂帳號組合，一鍵啟動特定群組）
Add - DefaultServer 與 DefaultLaunchArgs 功能（選填欄位，支援預設值）
Add - WindowInitDelay 參數化設定（可自訂視窗初始化等待時間）
Add - 選單顯示版本號、伺服器、權限狀態
Add - D2R_Launcher.bat 自動解除檔案封鎖功能
Fix - PS1 右鍵執行時閃退問題
Fix - param() 必須在腳本最前面的語法錯誤
Fix - 提權過程的錯誤處理

---

## [b0.9.0] - 2025-10-18

實作外部設定檔系統與自動提權功能。

Add - 自動提權功能（腳本自動檢測並請求管理員權限）
Add - 外部設定檔系統（config.ini）
Add - 除錯模式（-Debug 參數）
Add - 動態帳號載入（支援任意數量帳號）

---

## [Initial Release] - 2025-10-17

初始版本，實現 D2R 多開與自動登入功能。

Add - 多開功能與自動登入
Add - Handle 關閉機制（繞過遊戲多開限制）
Add - 視窗標題自訂功能（D2R: 編號 - 顯示名稱）
Add - Mutex 避免日誌衝突
