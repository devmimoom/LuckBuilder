# Plus 引導表單 — 版面優化建議

## 一、已實作優化（本輪）

- **卡片最大寬度**：大螢幕上卡片限制 `kMaxCardWidth`，置中顯示，避免過寬難讀。
- **步驟指示器**：小螢幕改為僅顯示圓點+數字（可選隱藏文字），減少擠壓。
- **按鈕區**：主步驟底部按鈕列統一 `minHeight: 48`、間距與視覺權重。
- **區塊間距**：Step 1 的 Segment / Topic / Product 區塊用統一 `_kSectionSpacing`。
- **內距常數**：卡片內距、按鈕間距抽成常數，方便日後微調。

## 二、建議可再考慮

| 項目 | 說明 | 優先 |
|------|------|------|
| **動態字級** | 標題/內文依 `MediaQuery.textScaler` 或 `textTheme` 略縮放，避免無障礙大字體爆版 | 中 |
| **Step 1 產品列表** | 產品過多時可設 `maxHeight` + 區塊內捲動，避免整卡過長 | 低 |
| **Step 3 時段 chips** | 小螢幕可改兩行或縮小 padding，避免單行過長 | 低 |
| **深色主題** | 目前為淺黃卡；若 App 支援深色，可依 `Theme.brightness` 切換卡面顏色 | 依產品 |
| **橫向 / 平板** | 大寬度時可改為左右分欄（左步驟、右表單），需額外 layout | 低 |

## 三、設計 token 對齊

- 卡片圓角、陰影、按鈕圓角已與 `app_tokens` 風格一致（暖色系）。
- 卡片 `maxWidth` 使用頁內常數 `_kCardMaxWidth`（420）；若需與全專案 `layout_constants` 對齊可改為 `kMaxCardWidth`。
