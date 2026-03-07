# App Store 上傳完整指南

---

## 📱 已上架 App — 提交更新（修改）步驟

若 App **已經在 App Store 上架**，要提交新版本請依下列步驟操作。

### 第 0 步：提高版本號與構建號（必做）

每次提交更新，**版本號或構建號必須比上一版更大**，否則無法上傳。

1. **改 Flutter 專案**  
   編輯 `pubspec.yaml`，找到 `version:`：
   - 小改動（修 bug、小優化）：只加構建號，例如 `1.0.0+5` → `1.0.0+6`
   - 有新功能：提高版本號並加構建號，例如 `1.0.0+5` → `1.0.1+6`  
   格式：`版本號+構建號`（例如 `1.0.1+6` 表示版本 1.0.1、構建 6）

2. **確認 Xcode 會讀到**  
   iOS 的 Version / Build 來自 Flutter（`FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER`），改完 `pubspec.yaml` 後用 Xcode 建檔即可，無需手動改 Xcode 裡的數字。

---

### 第 1 步：本地建檔（Archive）

1. 終端機執行：
   ```bash
   cd /Users/Ariel/開發中APP/LearningBubbles
   flutter clean
   flutter pub get
   cd ios && pod install && cd ..
   open ios/Runner.xcworkspace
   ```
2. 在 Xcode：
   - Scheme 選 **Runner**
   - Destination 選 **Any iOS Device (arm64)**（不要選模擬器）
3. 選單 **Product** → **Archive**，等建檔完成。
4. 建檔成功後會跳出 **Organizer**，裡面會有一個新的 Archive。

---

### 第 2 步：驗證 Archive（建議）

1. 在 Organizer 選剛建好的 Archive。
2. 點右側 **Validate App**。
3. 依序選：App Store Connect → 你的團隊 → 下一步，讓它跑完驗證。
4. 若有錯誤，依提示修正（常見：證書、描述檔、Bundle ID）。

---

### 第 3 步：上傳到 App Store Connect

1. 在 Organizer 同一個 Archive 點 **Distribute App**。
2. 選 **App Store Connect** → **Upload** → 選團隊。
3. 選項建議：
   - ✅ Upload your app's symbols
   - ✅ Manage Version and Build Number
4. 點 **Upload**，等上傳完成（約 10–30 分鐘）。

---

### 第 4 步：在 App Store Connect 建立新版本並選構建

1. 登入 [App Store Connect](https://appstoreconnect.apple.com)，進入你的 App（OnePop）。
2. 左側點 **App Store**，中間區塊選 **iOS App**。
3. 若已有「準備提交」的版本：
   - 在該版本頁面，到 **Build** 區塊點 **+**，選剛上傳的構建（會顯示新版本號與構建號），選 **Done**。
4. 若還沒有新版本：
   - 點 **+ Version** 或 **建立 iOS 版本**，輸入新版本號（要與 `pubspec.yaml` 的版本號一致，例如 `1.0.1`）。
   - 在 **Build** 區塊點 **+**，選剛上傳的構建 → **Done**。
5. 等構建狀態從「Processing」變成「Ready to Submit」（通常 10–30 分鐘）。

---

### 第 5 步：填寫「此版本的更新內容」

1. 在同一個版本頁面，找到 **此版本的更新內容**（What's New in This Version）。
2. 填寫使用者會看到的更新說明，例如：
   ```
   • 修正產品詳情頁封面顯示與圓角問題
   • 首頁 Banner 與卡片版面優化
   • 效能與穩定性改進
   ```
3. 其他欄位（描述、關鍵字、截圖等）若沒變可不必改；有改再更新。

---

### 第 6 步：送出審核

1. 檢查該版本頁面必填項是否都有（隱私政策、支援 URL、定價等沿用即可）。
2. 點右上角 **Submit for Review**。
3. 出口合規性問題照目前設定回答（若未改加密相關，選項與上次相同即可）。
4. 確認送出。

送出後會收到確認信；審核約 1–2 個工作天，狀態會在 App Store Connect 更新。

**更新流程快速勾選：**

| 步驟 | 動作 | 完成 |
|------|------|------|
| 0 | 在 `pubspec.yaml` 提高 `version`（例如 1.0.0+5 → 1.0.0+6 或 1.0.1+6） | ☐ |
| 1 | `flutter clean` → `pod install` → Xcode 開 `Runner.xcworkspace` → Product → Archive | ☐ |
| 2 | Organizer → Validate App | ☐ |
| 3 | Organizer → Distribute App → Upload | ☐ |
| 4 | App Store Connect → 選版本 → Build 區塊「+」選剛上傳的構建 | ☐ |
| 5 | 填寫「此版本的更新內容」 | ☐ |
| 6 | Submit for Review | ☐ |

> 目前專案版本為 `1.0.0+5`（見 `pubspec.yaml`），下次上傳請至少改為 `1.0.0+6` 或 `1.0.1+6`。

---

## 📋 上傳前最終檢查清單

### ✅ 已完成的配置檢查

- [x] **RevenueCat API Key**：已替換為生產環境 key (`appl_dZHavXTVfYphPHBbWqmWItspNOI`)
- [x] **加密出口合規性**：已添加 `ITSAppUsesNonExemptEncryption = false` 到 Info.plist
- [x] **測試代碼保護**：測試通知函數已用 `kDebugMode` 保護
- [x] **版本號**：`1.0.0+1`（版本號 1.0.0，構建號 1）
- [x] **Bundle ID**：`com.mimoom.onepop`
- [x] **開發團隊**：H7TSDR937Y
- [x] **隱私權限描述**：NSUserNotificationUsageDescription 已設置

### ⚠️ 需要確認的項目

- [ ] **App Store Connect 中的 App 已創建**：Bundle ID `com.mimoom.onepop` 已在 App Store Connect 註冊
- [ ] **IAP 產品已創建**：`credits_1`, `credits_3`, `credits_10` 已在 App Store Connect 中創建
- [ ] **隱私政策 URL**：已在 App Store Connect 填寫
- [ ] **支援 URL**：已在 App Store Connect 填寫
- [ ] **App 圖標**：1024x1024 圖標已準備好
- [ ] **截圖**：至少 1 張 iPhone 截圖已準備好

---

## 🚀 步驟一：構建 iOS Archive

### 1.1 清理專案

```bash
cd /Users/Ariel/開發中APP/LearningBubbles
flutter clean
flutter pub get
cd ios
pod install
cd ..
```

### 1.2 在 Xcode 中打開專案

```bash
open ios/Runner.xcworkspace
```

**重要**：必須打開 `.xcworkspace`，不是 `.xcodeproj`

### 1.3 選擇構建設定

1. 在 Xcode 頂部工具欄：
   - **Scheme**：選擇 `Runner`
   - **Destination**：選擇 `Any iOS Device (arm64)` 或 `Generic iOS Device`
   - **不要選擇模擬器**

2. 確認版本號：
   - 點擊專案導航器中的 `Runner`（藍色圖示）
   - 選擇 `Runner` target
   - 在 **General** 標籤頁確認：
     - **Version**：`1.0.0`
     - **Build**：`1`
     - **Bundle Identifier**：`com.mimoom.onepop`

### 1.4 構建 Archive

1. 選單：**Product** → **Archive**
2. 等待構建完成（可能需要幾分鐘）
3. 構建成功後，**Organizer** 視窗會自動打開

---

## ✅ 步驟二：驗證 Archive

### 2.1 在 Organizer 中驗證

1. 在 **Organizer** 視窗中，選擇剛構建的 Archive
2. 點擊右側的 **Validate App** 按鈕
3. 選擇 **App Store Connect** → **Next**
4. 選擇你的開發團隊 → **Next**
5. 等待驗證完成

**如果驗證失敗**：
- 檢查錯誤訊息
- 常見問題：
  - 證書過期：到 Xcode → Preferences → Accounts → 下載最新證書
  - Bundle ID 不匹配：確認 App Store Connect 中的 Bundle ID
  - 缺少必要權限：檢查 Info.plist

### 2.2 驗證通過後

驗證成功後，可以選擇：
- **Distribute App**：直接上傳到 App Store Connect
- 或稍後在 Organizer 中上傳

---

## 📤 步驟三：上傳到 App Store Connect

### 3.1 從 Organizer 上傳

1. 在 **Organizer** 中選擇 Archive
2. 點擊 **Distribute App**
3. 選擇 **App Store Connect** → **Next**
4. 選擇 **Upload** → **Next**
5. 選擇你的開發團隊 → **Next**
6. 確認選項：
   - ✅ **Upload your app's symbols**（建議勾選，用於崩潰報告）
   - ✅ **Manage Version and Build Number**（自動管理）
7. 點擊 **Upload**
8. 等待上傳完成（可能需要 10-30 分鐘）

### 3.2 使用命令行上傳（可選）

```bash
# 使用 xcodebuild 和 altool（需要 Xcode 13 或更早）
# 或使用 xcrun altool（Xcode 14+）
xcrun altool --upload-app \
  --type ios \
  --file "/path/to/your/app.ipa" \
  --apiKey YOUR_API_KEY \
  --apiIssuer YOUR_ISSUER_ID
```

---

## 📱 步驟四：在 App Store Connect 中完成提交

### 4.1 等待處理完成

1. 登入 [App Store Connect](https://appstoreconnect.apple.com)
2. 進入你的 App（OnePop）
3. 點擊 **App Store** 標籤頁
4. 等待構建處理完成（通常 10-30 分鐘）
   - 狀態會從「Processing」變為「Ready to Submit」

### 4.2 選擇構建版本

1. 在版本頁面，點擊 **+ Version** 或選擇現有版本
2. 在 **Build** 區塊，點擊 **+** 按鈕
3. 選擇剛上傳的構建（版本 1.0.0，構建 1）
4. 點擊 **Done**

### 4.3 填寫版本資訊

**必要欄位：**

1. **版本號**：`1.0.0`
2. **What's New in This Version**（版本說明）：
   ```
   OnePop 1.0.0 - 首次發布
   
   • 每日學習內容推播
   • 個人化學習進度追蹤
   • 多種學習主題與產品
   • 簡潔優雅的用戶介面
   ```
   （請根據實際功能填寫）

3. **關鍵字**：例如 `學習, 教育, 語言, 每日內容`
4. **描述**：填寫 App 的詳細描述
5. **宣傳文字**（可選）：簡短的宣傳語

### 4.4 上傳截圖和圖標

1. **App 圖標**：
   - 必須是 1024x1024 像素
   - PNG 格式，無透明度，無圓角
   - 位置：`ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`

2. **截圖**：
   - iPhone 6.7"（iPhone 14 Pro Max）：1290 x 2796 像素
   - iPhone 6.5"（iPhone 11 Pro Max）：1242 x 2688 像素
   - iPhone 5.5"（iPhone 8 Plus）：1242 x 2208 像素
   - 至少需要 1 張，最多 10 張
   - 位置：`app store images/` 目錄

### 4.5 配置 App 資訊

1. **App 名稱**：`OnePop`
2. **副標題**（可選）
3. **類別**：選擇適當的類別（例如：教育）
4. **內容版權**：`© 2025 mimoom`
5. **隱私政策 URL**：已填寫
6. **支援 URL**：已填寫

### 4.6 App 隱私設定

1. 點擊 **App 隱私** 標籤頁
2. 確認數據收集聲明：
   - **帳號資訊**：用戶 ID、電子郵件地址
   - **使用資料**：產品互動、應用程式互動
   - **診斷資料**：崩潰日誌、效能資料
3. 確認每個數據類型的用途說明

### 4.7 定價與可用性

1. **價格**：選擇價格（或免費）
2. **可用國家/地區**：選擇要發布的國家/地區
3. **年齡分級**：完成問卷調查

### 4.8 提交審核

1. 檢查所有必要欄位都已填寫
2. 點擊右上角 **Submit for Review**
3. 回答出口合規性問題：
   - **Does your app use encryption?** → 選擇 **Yes**
   - **Does your app qualify for any of the exemptions?** → 選擇 **Yes**（使用標準加密）
   - **App Uses Encryption** → 選擇 **No**（因為已設置 `ITSAppUsesNonExemptEncryption = false`）
4. 確認提交

---

## ⏱️ 審核時間

- **首次提交**：通常 1-3 個工作天
- **更新版本**：通常 1-2 個工作天
- 審核狀態會在 App Store Connect 中更新

---

## 🔍 常見問題排查

### 問題：Archive 構建失敗

**解決方案：**
- 確認選擇了正確的 Scheme（Runner）
- 確認選擇了「Any iOS Device」而非模擬器
- 檢查證書和描述檔是否有效
- 執行 `flutter clean` 和 `pod install`

### 問題：驗證失敗

**常見錯誤：**
- **Invalid Bundle**：檢查 Bundle ID 是否與 App Store Connect 一致
- **Missing Compliance**：確認已添加 `ITSAppUsesNonExemptEncryption`
- **Invalid Icon**：確認 1024x1024 圖標格式正確

### 問題：上傳失敗

**解決方案：**
- 檢查網路連接
- 確認 Apple ID 有上傳權限
- 嘗試使用 Xcode Organizer 而非命令行

### 問題：構建處理時間過長

**說明：**
- 處理時間通常為 10-30 分鐘
- 如果超過 1 小時，檢查 App Store Connect 是否有錯誤訊息
- 可以嘗試重新上傳

---

## 📝 上傳後檢查清單

- [ ] Archive 構建成功
- [ ] 驗證通過
- [ ] 上傳成功
- [ ] App Store Connect 中構建狀態為「Ready to Submit」
- [ ] 版本資訊已填寫完整
- [ ] 截圖已上傳
- [ ] 隱私政策 URL 已填寫
- [ ] 支援 URL 已填寫
- [ ] IAP 產品已配置
- [ ] 已提交審核

---

## 🎉 完成！

提交審核後，你會收到確認郵件。審核完成後，App 就會在 App Store 上架！

**後續步驟：**
- 監控審核狀態
- 準備回應審核團隊的問題（如有）
- 審核通過後，App 會自動上架
