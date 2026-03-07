# RevenueCat 生產環境設定指南（步驟二起）

從「建立生產環境 App Store 連接」到「取得並貼上生產環境 API Key」的完整做法。

---

## 步驟二：在 RevenueCat 建立／連接生產環境 App Store

### 2.1 進入專案與 Apps

1. 登入 [RevenueCat](https://app.revenuecat.com)。
2. 左側選單點 **Projects**，選 **OnePop**。
3. 左側選單點 **Apps**（或 **Project settings** → **Apps**）。

### 2.2 新增或選擇 iOS App

- **若已有 iOS App 且是「Test Store」：**
  - 點進該 App。
  - 檢查是否有 **Production** / **App Store** 的 Store 可選；若沒有，需新增 App Store 連接（見下方 2.3）。
- **若還沒有 iOS App：**
  - 點 **+ New**（或 **Add app**）。
  - 選 **Apple App Store**。
  - **App name** 填：`OnePop`（或與 App Store Connect 一致）。
  - **Bundle ID** 填：`com.mimoom.onepop`（須與 Xcode / App Store Connect 完全一致）。
  - 儲存。

### 2.3 連接 App Store Connect（取得生產環境資料）

1. 在該 App 的設定頁找到 **App Store Connect** 或 **Store connection** 區塊。
2. 點 **Connect** 或 **Link App Store Connect**。
3. 依畫面指示：
   - 使用 **App Store Connect API Key**（推薦），或
   - 使用 **Apple ID 登入** 授權。
4. **若用 API Key（推薦方式）：**
   
   **4.1 在 App Store Connect 建立 API Key：**
   - 開啟 [App Store Connect](https://appstoreconnect.apple.com)
   - 點右上角你的名字 → **帳號設定**（Account Settings）
   - 左側選單點 **整合**（Integrations）→ **App Store Connect API**
   - 點 **產生 API 金鑰**（Generate API Key）或 **+** 按鈕
   - 填寫：
     - **名稱**：例如 `RevenueCat OnePop`
     - **存取權限**：至少勾選 **App 管理**（App Manager）或 **Sales 和報告**（Sales and Reports）的讀取權限
   - 點 **產生**（Generate）
   - **重要**：下載 `.p8` 檔案（只會顯示一次，務必下載並保存）
   - 記下頁面上顯示的：
     - **Issuer ID**（UUID 格式，例如 `57246542-96fe-1a63-e053-0824d0110xxx`）
     - **Key ID**（較短的字串，例如 `ABC123DEFG`）
   
   **4.2 在 RevenueCat 填入 P8 Key 資訊：**
   - 回到 RevenueCat 的「In-app purchase key configuration」頁面
   - **P8 key file**：點上傳區域，選擇剛下載的 `.p8` 檔案（檔案名稱格式：`AuthKey_XXXXXXXXXX.p8` 或 `SubscriptionKey_XXXXXXXXXX.p8`）
   - **Key ID**：貼上從 App Store Connect 複製的 Key ID
   - **Issuer ID**：貼上從 App Store Connect 複製的完整 Issuer ID（UUID 格式）
   - 確認沒有驗證錯誤後，繼續下一步
   - 選擇對應的 **App**（OnePop）與 **Shared Secret**（若有 In-App Purchase）
5. 儲存後，RevenueCat 會同步 App Store Connect 的 app 與 IAP 產品，此時才會出現「生產環境」用的資料。

### 2.4 確認 IAP 產品在 RevenueCat

1. 左側選 **Products**（或該 App 底下的 **Products**）。
2. 確認有 **credits_1**、**credits_3**、**credits_10**，且對應到 App Store Connect 的 IAP 產品 ID。
3. 若沒有，在 App Store Connect 建立好 IAP 後，回 RevenueCat 重新同步或手動新增 Product ID。

---

## 步驟三：取得生產環境的 Public API Key

### 3.1 打開 API Keys 頁

1. 仍在 RevenueCat **OnePop** 專案。
2. 左側選 **API keys**（或 **Project** → **API keys**）。

### 3.2 區分測試與生產 Key

- **SDK API keys** 表格裡會有一或多筆：
  - **Test Store**：對應測試環境，key 為 `test_` 開頭。
  - **App Store** / **Production** / 或你的 App 名稱：對應生產環境，key 為 `appl_` 開頭。

### 3.3 複製生產環境 Key

1. 找到 **不是** "Test Store" 的那一筆（即生產環境）。
2. 點該行的 **• Show key**。
3. 複製顯示的 **Public API key**（整串，開頭為 `appl_`）。

若此時只有 "Test Store"、沒有生產環境 key，代表尚未完成步驟二（App Store Connect 連接或 App/Store 設定未完成），需回到步驟二檢查。

---

## 步驟四：把 Key 貼到專案

1. 開啟 `lib/iap/credits_iap_service.dart`。
2. 找到第 6 行左右的：
   ```dart
   const String _revenueCatAppleApiKey = ''; // 生產環境：...
   ```
3. 在空字串中貼上剛複製的 **生產環境** Public API Key，例如：
   ```dart
   const String _revenueCatAppleApiKey = 'appl_xxxxxxxxxxxxxxxxxxxxxxxx';
   ```
4. 存檔。

---

## 檢查清單（步驟二起）

- [ ] RevenueCat 專案內已有 iOS App（Bundle ID: `com.mimoom.onepop`）。
- [ ] 已連接 App Store Connect（API Key 或 Apple 登入）。
- [ ] Products 中有 credits_1 / credits_3 / credits_10。
- [ ] API keys 頁有「非 Test Store」的 SDK key（`appl_` 開頭）。
- [ ] 已將該 key 貼到 `credits_iap_service.dart` 並存檔。

若某一步的按鈕或選單名稱與上述不同，可依 RevenueCat 畫面上的「Connect」、「Link」、「App Store」等關鍵字找到對應項目；完成步驟二後，生產環境 key 就會出現在 API keys 頁。
