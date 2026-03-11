  mmk                           # OnepopNotificationContent — Xcode 詳細步驟

以下為「把 Swift / Info.plist 掛到 target」「加 App Groups」「設 Bundle ID 與簽名」的逐步操作。

---

## 一、把 NotificationViewController.swift 與 Info.plist 掛到 target（或替換）

### 1.1 確認要用的檔案在哪裡

- 專案裡要用的檔案路徑是：**`ios/OnepopNotificationContent/`** 底下的  
  **`NotificationViewController.swift`** 和 **`Info.plist`**（即本 README 同一個資料夾）。

### 1.2 做法 A：只替換內容（Xcode 裡已經有這兩個檔）

1. 在 Xcode **左側 Project Navigator** 展開 **Runner** 專案，找到 **OnepopNotificationContent** 群組。
2. 點選底下的 **NotificationViewController**（Swift 圖示）。
3. 右側會顯示程式碼。用 **Cursor /  Finder** 開啟 `ios/OnepopNotificationContent/NotificationViewController.swift`，**全選複製**，回到 Xcode 把編輯器裡的內容**全選後貼上覆蓋**，再 **⌘S 儲存**。
4. 在左側改點 **Info**（plist 圖示），右側會顯示 Key-Value 表。
5. 用 **Cursor / 文字編輯器** 開啟 `ios/OnepopNotificationContent/Info.plist`，**整份複製**。在 Xcode 若要改 plist 原始碼：對 **Info** 按右鍵 → **Open As → Source Code**，再全選貼上覆蓋並儲存。
6. 確認這兩個檔的 **Target Membership**：點選該檔案後，在 **右側 File Inspector**（⌘⌥1）最下方 **Target Membership** 區塊，**OnepopNotificationContent** 必須勾選；若 **Runner** 有勾選可取消（Extension 的檔不要給主 App 編譯）。

### 1.3 做法 B：改為直接參考專案目錄的檔案（Xcode 的檔不在 ios/OnepopNotificationContent/ 時）

1. 在左側 **OnepopNotificationContent** 群組裡，對 **NotificationViewController** 按右鍵 → **Delete**。
2. 在彈出視窗選 **Remove Reference**（不要選 Move to Trash）。
3. 對 **Info** 同樣 **Delete → Remove Reference**。
4. 對 **OnepopNotificationContent** 群組（資料夾圖示）按右鍵 → **Add Files to "Runner"…**（或你的專案名稱）。
5. 在檔案選擇視窗中，導航到專案目錄下的 **ios/OnepopNotificationContent/**，選取：
   - **NotificationViewController.swift**
   - **Info.plist**  
   （可按住 ⌘ 多選）
6. 在對話框下方：
   - **Add to targets**：**只勾選 OnepopNotificationContent**（不要勾 Runner）。
   - **Copy items if needed**：可不勾。
7. 點 **Add**。
8. 再檢查：點選 **NotificationViewController.swift**，右側 **Target Membership** 只有 **OnepopNotificationContent** 勾選；**Info** 同理。

### 1.4 若還有 MainInterface.storyboard（選用）

- 我們用純程式 UI，不需要 Storyboard。若左側有 **MainInterface**：
  - 選 **OnepopNotificationContent** target → **Build Phases** → **Copy Bundle Resources**，若有 **MainInterface.storyboard** 可點 **-** 移除，避免多餘資源。

---

## 二、在 OnepopNotificationContent target 加入 App Groups

1. 在 Xcode **左側** 點選最上方 **專案圖示（藍色）**，即開啟專案設定。
2. 中間 **TARGETS** 列表（不是 PROJECT）點選 **OnepopNotificationContent**。
3. 上方分頁列點 **Signing & Capabilities**。
4. 在 **Signing & Capabilities** 區塊內，點 **+ Capability** 按鈕。
5. 在搜尋框輸入 **App Groups**，雙擊 **App Groups** 加入。
6. 加入後會出現 **App Groups** 區塊，底下有列表。點列表左側的 **+**。
7. 輸入：**`group.com.onepop.shared`**，按 **OK**。
8. 確認列表中出現 **group.com.onepop.shared** 且左側為勾選狀態。

（主 App **Runner** 的 `group.com.onepop.shared` 已寫在 **Runner.entitlements**；若在 Runner target 的 Signing & Capabilities 沒看到 App Groups，可同樣用 **+ Capability** 加入 **App Groups** 並新增 **group.com.onepop.shared**。）

---

## 三、設定 Extension 的 Bundle ID 與簽名

1. **TARGETS** 仍選 **OnepopNotificationContent**，分頁仍在 **Signing & Capabilities**（或 **General** 看 Bundle ID）。
2. **Bundle Identifier**  
   - 在 **General** 分頁可看到 **Bundle Identifier** 欄位。  
   - 格式必須是：**主 App 的 Bundle ID + `.OnepopNotificationContent`**。  
   - 例如主 App 是 **Runner** 且 Bundle ID 為 `hjh.Runner`，則 Extension 填：**`hjh.Runner.OnepopNotificationContent`**。  
   - 若主 App 是 `com.onepop.app`，則填：**`com.onepop.app.OnepopNotificationContent`**。  
   - 到 **TARGETS → Runner → General** 可查看主 App 的 **Bundle Identifier**，照抄後再加 `.OnepopNotificationContent` 即可。
3. **簽名（Signing）**  
   - 在 **Signing & Capabilities** 分頁找到 **Signing** 區塊。  
   - 勾選 **Automatically manage signing**。  
   - **Team** 下拉選與主 App（Runner）**同一個 Team**。  
   - 若出現 Provisioning profile 錯誤：可先選 **Team → None** 再改回正確 Team；或到 [Apple Developer](https://developer.apple.com/account) → **Certificates, Identifiers & Profiles** 確認該 App ID 已建立且含 **App Groups** capability，再回 Xcode 重選 Team。
4. **Deployment Target（選用）**  
   - 切到 **General** 分頁，**Minimum Deployments** 設成與 **Runner** 相同（例如 iOS 12.0），避免版本不一致。

---

## 四、建置與測試

1. 上方 scheme 選 **Runner**，裝置選 **實機**（建議，Extension 展開在模擬器可能不完整）。
2. **Product → Build**（⌘B），確認 **OnepopNotificationContent** 與 Runner 都無編譯錯誤。
3. 裝到手機後，由 Flutter 主 App 觸發一則 **category 為 ONEPOP_DEEP_DIVE** 的本地通知，在鎖定畫面或通知中心**長按該則通知**，應看到自訂展開 UI（分類、正文、深度解析、來源、按鈕）。

若展開仍是系統預設樣式，請檢查：

- Flutter 發送的通知 `categoryIdentifier` 是否為 **ONEPOP_DEEP_DIVE**（`NotificationService` 已預設）。
- Extension 的 **Info.plist** 裡 **NSExtensionAttributes → UNNotificationExtensionCategory** 是否為 **ONEPOP_DEEP_DIVE**。
