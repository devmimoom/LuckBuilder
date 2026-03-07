# Archive / 上傳前完整檢查清單

重新 Archive 與上傳前，依序確認以下項目，避免常見錯誤。

---

## 一、版本與建置號（最容易錯）

| 項目 | 位置 | 說明 |
|------|------|------|
| **版本號一致** | `pubspec.yaml` → `version:` | 目前為 `1.0.0+3`。格式：`主.次.修+Build號` |
| **Build 號必須遞增** | 同上，`+` 後數字 | 每次上傳到 App Store Connect 的 **Build 號必須大於** 已上傳過的。若曾上傳過 1、2，這次用 3；若全新上傳可用 1 |
| **iOS 讀取 Flutter 版本** | `ios/Flutter/Generated.xcconfig` | 由 `flutter build` 產生，會從 pubspec 帶入 `FLUTTER_BUILD_NAME`、`FLUTTER_BUILD_NUMBER`，勿手動改此檔 |

**建議**：上傳前到 [App Store Connect](https://appstoreconnect.apple.com) → 你的 App → TestFlight，查看「已上傳的 Build」最大編號，將 `pubspec.yaml` 的 `+N` 改為比它大 1。

---

## 二、Bundle ID 與簽名

| 項目 | 位置 | 確認內容 |
|------|------|----------|
| **Bundle ID** | Xcode：Runner target → Signing | 必須為 `com.mimoom.onepop`（與 App Store Connect 建立的 App 一致） |
| **開啟專案方式** | 終端 / Finder | 一律開 **`ios/Runner.xcworkspace`**，不要開 `.xcodeproj` |
| **Archive 目標** | Xcode 上方 Destination | 選 **Any iOS Device (arm64)** 或接上的實機，**不可選模擬器** |
| **Signing Team** | Runner → Signing & Capabilities | 已選正確 Team（例如 H7TSDR937Y），且無紅色錯誤 |

---

## 三、Info.plist 與權限

| 項目 | 檔案 | 確認 |
|------|------|------|
| **顯示名稱** | `ios/Runner/Info.plist` | `CFBundleDisplayName`、`CFBundleName` 為 **OnePop**（與商店名稱一致） |
| **通知說明** | 同上 | `NSUserNotificationUsageDescription` 已填（目前：We use notifications to deliver daily content from OnePop.） |
| **加密出口** | 同上 | `ITSAppUsesNonExemptEncryption` = **false**（無自訂加密可填 false，避免出口審查） |

---

## 四、RevenueCat / IAP

| 項目 | 位置 | 確認 |
|------|------|------|
| **API Key 為生產環境** | `lib/iap/credits_iap_service.dart` | `_revenueCatAppleApiKey` 為 **`appl_` 開頭**（非 `test_`） |
| **App Store Connect IAP** | 網頁 | `credits_1`、`credits_3`、`credits_10` 已建立且狀態可提交 |

---

## 五、除錯與日誌（避免上架後仍寫入本機路徑）

| 項目 | 說明 |
|------|------|
| **debugPrint** | Release 建置時 Flutter 會將 `debugPrint` 視為 no-op，不會輸出，可保留 |
| **kDebugMode 保護** | 測試用邏輯（如測試通知）若僅在除錯時呼叫，可接受 |
| **硬編碼本機路徑** | `lib/bubble_library/notifications/notification_service.dart` 內有寫入 `File('/Users/Ariel/開發中APP/LearningBubbles/.cursor/debug.log')`，未包在 `kDebugMode`。上架後在用戶裝置該路徑不存在，會拋錯但被 `catch (_)` 吃掉，**不會崩潰**。若希望完全避免，可將該段用 `if (kDebugMode) { ... }` 包住 |

---

## 六、圖示與啟動圖

| 項目 | 位置 | 確認 |
|------|------|------|
| **App 圖示 1024** | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` | 存在且為 1024×1024，無透明、無圓角 |
| **LaunchScreen** | `ios/Runner/Base.lproj/LaunchScreen.storyboard` | 無紅線、顯示正常 |

---

## 七、建置與上傳指令

在專案根目錄執行：

```bash
cd "/Users/Ariel/開發中APP/LearningBubbles"
flutter clean
flutter pub get
flutter build ipa --release
```

- 成功後 Archive 在：`build/ios/archive/Runner.xcarchive`
- 若用指令匯出 IPA，通常會在 `build/ios/ipa/`（檔名可能為專案名或 Runner，依 Flutter 版本而定）

上傳方式二選一：

1. **Xcode Organizer**：Window → Organizer → Archives → 選 Runner → Distribute App → App Store Connect → Upload  
2. **Transporter**：先從 Xcode 匯出 IPA 或依 Flutter 輸出路徑取得 `.ipa`，用 Transporter 上傳

---

## 八、上傳後在 App Store Connect

- 新版本：左側 App Store → iOS App → 新增版本，填版本號（如 1.0.0）
- **建置版本**：選剛上傳的 Build（例如 1.0.0 (3)）
- 填寫說明、關鍵字、截圖、隱私政策 URL、支援 URL（見 `docs/US_MARKET_ASO_AND_CHECKLIST.md`）
- 儲存後「提交以供審核」

---

## 九、Archive 一直跑不起來（排錯步驟）

依序嘗試，多數情況可解決：

### 1. 用 Xcode 做 Archive（較容易看到錯誤）

- 開啟 **`ios/Runner.xcworkspace`**（不要開 .xcodeproj）
- 上方 **Destination** 選 **Any iOS Device (arm64)**
- 選單 **Product** → **Clean Build Folder**（Shift+Cmd+K）
- 選單 **Product** → **Archive**
- 若失敗，看 **左側 Issue navigator（⚠️）** 或 **Report navigator** 點最後一次建置，把**紅色錯誤訊息**記下來

### 2. 簽名與憑證

- 左側選 **Runner** 專案 → 選 **Runner** target → **Signing & Capabilities**
- **Team** 選你的 Apple 開發者帳號（例如 H7TSDR937Y）
- 若有紅色錯誤：「No signing certificate」→ Xcode 選單 **Xcode** → **Settings** → **Accounts** → 你的 Apple ID → **Manage Certificates**，點 **+** 新增 **Apple Development** 或 **Apple Distribution**

### 3. 先讓 iOS 編譯成功（不一定要 Archive）

- Destination 改選 **模擬器**（例如 iPhone 16）
- **Product** → **Build**（Cmd+B）
- 若這裡就編譯失敗，先修這裡的錯誤（例如缺少套件、Swift 錯誤），修好後再回來做 Archive

### 4. 用指令建置（終端機）

在專案根目錄執行：

```bash
cd "/Users/Ariel/開發中APP/LearningBubbles"
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ipa --release
```

- **第一次** `flutter build ipa` 可能要 **5～15 分鐘**，中間會卡在 "Running Xcode build..." 是正常，請耐心等
- 若最後出現錯誤，把**整段錯誤訊息**複製下來，對照下面「常見失敗與對策」或搜尋該錯誤

### 5. 仍失敗時請保留的資訊

- Xcode 的 **完整錯誤訊息**（紅字或 Report 裡的 log）
- 或終端機執行 `flutter build ipa --release` 的**完整輸出**
- 有無出現「Signing for Runner requires a development team」「Provisioning profile」等字樣

---

## 十、常見失敗與對策

| 狀況 | 對策 |
|------|------|
| Archive 失敗 / 簽名錯誤 | Xcode → Product → Clean Build Folder；確認 Destination 為 Any iOS Device；檢查 Signing Team 與憑證 |
| 上傳時「Invalid Bundle」 | 確認 Bundle ID 與 App Store Connect 一致；確認版本/Build 號大於已上傳 |
| 上傳後 Processing 很久 | 正常，可等數分鐘到數十分鐘；若超過 1 小時可看郵件是否有錯誤通知 |
| 審核被拒（2.1） | 多為 App 不完整或閃退，本機用 Release 跑一次、確認無必現崩潰 |

---

## 十一、與本專案文件對照

- **步驟詳解**：`docs/ARCHIVE_上傳步驟.md`
- **ASO / 商店文案與隱私**：`docs/US_MARKET_ASO_AND_CHECKLIST.md`
- **上傳指南**：`docs/APP_STORE_UPLOAD_GUIDE.md`

以上檢查完成後再執行 Archive 與上傳，可大幅降低因版本、簽名或設定錯誤導致的失敗。
