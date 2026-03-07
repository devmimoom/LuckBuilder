# OnePop — Archive 與上傳 App Store 步驟

## 一、建置 Archive（指令）

在專案根目錄執行：

```bash
cd "/Users/Ariel/開發中APP/LearningBubbles"
flutter clean
flutter pub get
flutter build ipa --release
```

- 完成後會產生：`build/ios/archive/Runner.xcarchive`
- 若只做到這裡，IPA 可能尚未匯出，需用下面「方法 A」從 Xcode 匯出並上傳

---

## 二、上傳到 App Store Connect

任選一種方式即可。

### 方法 A：用 Xcode Organizer（推薦）

1. 開啟 Xcode 專案  
   - 雙擊 **`ios/Runner.xcworkspace`**（不要開 .xcodeproj）

2. 打開 Organizer  
   - 選單 **Window** → **Organizer**  
   - 左側點 **Archives**

3. 選 Archive  
   - 若列表裡已有 **Runner**（版本 1.0.0），直接選它  
   - 若沒有，先建 Archive：**Product** → **Archive**（需選實機或「Any iOS Device」）

4. 上傳  
   - 選好 Archive 後按 **Distribute App**  
   - 選 **App Store Connect** → **Next**  
   - 選 **Upload** → **Next**  
   - 勾選選項（通常預設即可）→ **Next**  
   - 選 **Automatically manage signing**（或你的 Team）→ **Next**  
   - 確認摘要 → **Upload**  
   - 等上傳完成

5. 到 App Store Connect 確認  
   - 打開 [App Store Connect](https://appstoreconnect.apple.com)  
   - 你的 App → **TestFlight** 或 **App Store** 分頁  
   - 幾分鐘後會出現新 build（版本 1.0.0，Build 1）

---

### 方法 B：用 Transporter

1. 先產生 IPA（若還沒有）  
   - 用 **方法 A** 的 Xcode Organizer 選 Archive → **Distribute App**  
   - 選 **App Store Connect** → **Upload**  
   - 在最後一步前改選 **Export**（不要選 Upload），選一個資料夾匯出  
   - 會得到一個 `.ipa` 檔

2. 或用指令匯出 IPA（已有 archive 時）  
   ```bash
   cd "/Users/Ariel/開發中APP/LearningBubbles"
   flutter build ipa --release
   ```  
   - 完成後 IPA 在：`build/ios/ipa/OnePop.ipa`

3. 用 Transporter 上傳  
   - 開啟 **Transporter**（Mac App Store 可下載）  
   - 登入與 App Store Connect 相同的 Apple ID  
   - 把 **OnePop.ipa** 拖進視窗  
   - 按 **交付**，等上傳完成

4. 到 App Store Connect 確認  
   - 同方法 A 第 5 步

---

## 三、上傳前快速檢查

| 項目 | 確認 |
|------|------|
| 版本號 | `pubspec.yaml` 為 `1.0.0+1`（1.0.0 build 1） |
| Bundle ID | `com.mimoom.onepop` |
| 簽名 | Xcode 中 Runner target → Signing 已選好 Team |
| 實機/目標 | Archive 時選 **Any iOS Device** 或接上的 iPhone |

---

## 四、若 Archive 失敗

1. **flutter clean && flutter pub get** 再建一次  
2. 用 Xcode 開 **ios/Runner.xcworkspace**，選 **Product** → **Clean Build Folder**，再 **Product** → **Archive**  
3. 確認證書：**Xcode** → **Settings** → **Accounts** → 你的 Apple ID → **Manage Certificates**，必要時下載/更新  
4. 確認裝置：選單選 **Any iOS Device (arm64)**，不要選模擬器

---

## 五、上傳後在 App Store Connect

1. 到 **我的 App** → 選 **OnePop**  
2. 若為新版本：左側 **App Store** → **iOS App** → **+ 版本或平台**，填 1.0.0  
3. **建置版本**：選剛上傳的 build（1.0.0 (1)）  
4. 填妥說明、關鍵字、截圖、隱私政策 URL、支援 URL 等（見 `docs/US_MARKET_ASO_AND_CHECKLIST.md`）  
5. 儲存後送審：**提交以供審核**
