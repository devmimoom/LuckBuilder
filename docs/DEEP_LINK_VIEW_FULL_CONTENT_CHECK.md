# Deep Link（View full content）完整邏輯檢查

## 端到端流程

```
Extension 點「查看完整內容」
  → didTapOpenApp() 組 onepop://open?productId=...&contentItemId=...
  → extensionContext?.open(url)
  → iOS 喚起/帶回主 App
  → application(_:open:url:options:) 寫入 static，並 invokeMethod("checkPendingDeepLink")（若 channel 已就緒）
  → Flutter 於三種時機之一呼叫 getPendingDeepLink → 取回並清空 → push DetailPage / ProductLibraryPage
```

## 1. Extension（NotificationViewController.swift）

- **didReceive**：從 userInfo/payload 解析 `contentItemId`、`itemId`、`productId`（line 110–113）。
- **didTapOpenApp**（line 293–301）：組 `onepop://open`，query 為 `productId`、`contentItemId`（空時用 `itemId`），呼叫 `extensionContext?.open(url)`。
- **結論**：Extension 端正確，主 App 收到 URL 後可取得該則卡片的 contentItemId。

## 2. iOS AppDelegate

- **Static 變數**：`pendingDeepLinkProductId`、`pendingDeepLinkContentItemId`；寫入時機為 `application(_:open:url:options:)`（line 65–70），僅在 `scheme == "onepop"` 且 `host == "open"` 時寫入。
- **getPendingDeepLink**（line 21–27）：回傳當前 static 值並**立即清空**（nil），同一筆 link 只會被消耗一次。
- **deepLinkChannel**：存成實例變數（line 9），在 `didFinishLaunchingWithOptions` 建立並設定 handler；在 `application:open:url` 寫入 static 後呼叫 `invokeMethod("checkPendingDeepLink", arguments: nil)`（line 71），讓「App 已在前景」時 Flutter 也會檢查。
- **結論**：寫入、消耗、通知 Flutter 的邏輯正確。若 URL 無 query 或解析為空字串，static 為 ""，getPendingDeepLink 仍會回傳空字串，Flutter 不 push，行為正確。

## 3. Flutter Bootstrapper（bootstrapper.dart）

### 3.1 單一 channel

- `const _deepLinkChannel = MethodChannel('com.onepop.deeplink')`（line 33）：同一 channel 用於 (1) Flutter → Native：`invokeMapMethod('getPendingDeepLink')`；(2) Native → Flutter：`setMethodCallHandler` 接收 `checkPendingDeepLink`。雙向使用正確。

### 3.2 註冊與清理

- **initState**（line 39–46）：僅在 `Platform.isIOS` 時 `addObserver` 與 `_deepLinkChannel.setMethodCallHandler(_onDeepLinkChannelCall)`，避免 Android 誤用。
- **dispose**（line 58–65）：移除 observer 並 `setMethodCallHandler(null)`，避免 dispose 後仍處理 native 呼叫。
- **結論**：生命週期正確。

### 3.3 三種檢查時機

| 時機 | 觸發 | 延遲 | mounted 檢查 |
|------|------|------|----------------|
| 冷啟動 | didChangeDependencies → addPostFrameCallback | 150ms | 延遲回調內 |
| 溫啟動 | didChangeAppLifecycleState(resumed) | 150ms | 延遲回調內 |
| App 已在前景 | Native invokeMethod("checkPendingDeepLink") | addPostFrameCallback（下一幀） | 回調內 |

- 冷、溫啟動皆延遲 150ms，可降低早於 `application:open:url` 的 race。
- 「App 已在前景」由 native 在寫入 static 後主動通知，無需延遲；Flutter 用 addPostFrameCallback 確保在下一幀、context 有效時再呼叫 _checkPendingDeepLink。
- **結論**：三條路徑時序與 mounted 檢查一致且完整。

### 3.4 _onDeepLinkChannelCall（line 48–55）

- 僅處理 `call.method == 'checkPendingDeepLink'`。
- 使用 `addPostFrameCallback` 再執行 `_checkPendingDeepLink()`，並在回調內檢查 `mounted`。
- **結論**：正確，避免在錯誤時機使用 context。

### 3.5 _checkPendingDeepLink（line 101–120）

- 開頭 `if (!mounted) return`。
- `map = await _deepLinkChannel.invokeMapMethod(...)` 後再次 `if (!mounted || map == null) return`。
- 先 `contentItemId.isNotEmpty` → DetailPage；否則 `productId.isNotEmpty` → ProductLibraryPage；與 Extension 傳入的「該則卡片」語意一致。
- `Navigator.of(context).push(...)`：Bootstrapper 為 MaterialApp 的祖先（見 main.dart 114–138），context 可正確找到 MaterialApp 的 Navigator。
- **結論**：消耗一次、優先 contentItemId、導航對象正確；mounted 與 null 檢查完整。

### 3.6 didChangeDependencies 與 _inited（line 123–126, 387–395）

- `_inited` 僅在首次 `didChangeDependencies` 設為 true，冷啟動的 addPostFrameCallback + 150ms 延遲只會排程一次。
- **結論**：不會重複註冊或重複排程冷啟動檢查。

## 4. 邊界與重複觸發

- **冷啟動後馬上又 resumed**：冷啟動排程 150ms 後檢查；resumed 也排程 150ms 後檢查。第一次檢查會消耗 link 並 push；第二次檢查取回空值，不 push。無重複導向。
- **App 已在前景，連續兩次 open URL**：每次 open 都會寫入 static 並 invoke checkPendingDeepLink。第一次檢查消耗第一筆並 push；第二次檢查消耗第二筆並再 push（兩次導向，符合兩次點擊）。若實務上不會短時間點兩次，可接受。
- **dispose 後 native 才 invoke**：dispose 已設 `setMethodCallHandler(null)`，若引擎仍送來訊息，可能無 handler 或由引擎處理，不會再呼叫已 dispose 的 state。安全。
- **Extension payload 缺 contentItemId / productId**：URL 可能為空 query 或空值，解析後為 ""，不 push。合理。

## 5. 總結

- Extension 組 URL 與開 App、AppDelegate 寫入/消耗/通知、Flutter 三時機檢查與 _checkPendingDeepLink 邏輯、mounted 與延遲使用皆正確。
- Navigator 來自 MaterialApp，Bootstrapper 的 context 可找到，導航有效。
- 無發現邏輯錯誤或遺漏；實作與註解一致，可依此文件做回歸驗證（冷啟動、溫啟動、App 已在前景各點一次「查看完整內容」應皆進入該則卡片詳情）。
