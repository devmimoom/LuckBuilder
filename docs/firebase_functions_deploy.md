# Firebase Functions 部署清單

這份清單是照目前專案的 webhook 實作整理，目標是讓你可以直接複製指令部署 `RevenueCat -> Firebase Functions -> Firestore`。

## 0. 前置條件
- 已安裝 `Firebase CLI`
- 已有 Firebase 專案
- 已啟用：
  - `Firestore`
  - `Cloud Functions`
  - `Artifact Registry`
  - `Cloud Build`
  - `Secret Manager`
- 本機可執行：
  - `node -v`
  - `npm -v`
  - `firebase --version`

建議版本：
- Node.js `20.x`
- Firebase CLI 最新版

## 1. 首次登入 Firebase

```bash
firebase login
```

確認目前登入狀態：

```bash
firebase login:list
```

## 2. 綁定 Firebase 專案

先查看可用專案：

```bash
firebase projects:list
```

在專案根目錄執行：

```bash
cd "/Users/Ariel/開發中APP/LuckLab"
firebase use --add
```

執行後：
- 選你的 Firebase project
- alias 建議取 `prod` 或 `lucklab`

完成後會產生 `.firebaserc`。

如果你想直接指定：

```bash
firebase use <your-project-id>
```

## 3. 安裝 functions 依賴

```bash
cd "/Users/Ariel/開發中APP/LuckLab/functions"
npm install
```

## 4. 設定 RevenueCat secrets

目前程式使用 Firebase Secret Manager，所以請直接設定 secrets：

```bash
cd "/Users/Ariel/開發中APP/LuckLab"
firebase functions:secrets:set REVENUECAT_WEBHOOK_AUTH
firebase functions:secrets:set REVENUECAT_SECRET_API_KEY
```

執行時輸入你要給 RevenueCat webhook 用的 token，例如：

```text
your_webhook_bearer_token
```

`REVENUECAT_WEBHOOK_AUTH` 是給 RevenueCat webhook 用的 Bearer token。  
`REVENUECAT_SECRET_API_KEY` 則是 RevenueCat 的 server-side secret API key，供 `syncSubscriptionStatus` callable 主動向 RevenueCat 查詢使用者權限。

檢查 secret 是否存在：

```bash
firebase functions:secrets:access REVENUECAT_WEBHOOK_AUTH
firebase functions:secrets:access REVENUECAT_SECRET_API_KEY
```

如果要更新：

```bash
firebase functions:secrets:set REVENUECAT_WEBHOOK_AUTH
```

如果要刪除：

```bash
firebase functions:secrets:destroy REVENUECAT_WEBHOOK_AUTH
```

## 5. 本機檢查 TypeScript

```bash
cd "/Users/Ariel/開發中APP/LuckLab/functions"
npm run lint
```

如果你要先編譯：

```bash
npm run build
```

## 6. 部署 Functions

回到專案根目錄：

```bash
cd "/Users/Ariel/開發中APP/LuckLab"
firebase deploy --only functions
```

如果你只想部署訂閱相關 Functions：

```bash
firebase deploy --only functions:revenueCatWebhook,functions:syncSubscriptionStatus
```

部署完成後，CLI 會顯示 URL。  
本專案目前訂閱相關 function 名稱是：

```text
revenueCatWebhook
syncSubscriptionStatus
```

region 是：

```text
asia-east1
```

所以 URL 會是這種格式：

```text
https://asia-east1-<your-project-id>.cloudfunctions.net/revenueCatWebhook
```

## 7. RevenueCat Dashboard 設定

到 RevenueCat 後台設定 webhook：

- URL：

```text
https://asia-east1-<your-project-id>.cloudfunctions.net/revenueCatWebhook
```

- Authorization：

```text
Bearer your_webhook_bearer_token
```

- 建議勾選事件：
  - `INITIAL_PURCHASE`
  - `RENEWAL`
  - `PRODUCT_CHANGE`
  - `CANCELLATION`
  - `UNCANCELLATION`
  - `BILLING_ISSUE`
  - `EXPIRATION`
  - `TRANSFER`

## 8. 部署後立即驗證

### 8.1 用 RevenueCat 測試 webhook
在 RevenueCat webhook 頁送一個 test event。

### 8.2 看 Firebase logs

```bash
cd "/Users/Ariel/開發中APP/LuckLab"
firebase functions:log --only revenueCatWebhook
```

### 8.3 部署 Firestore Rules

```bash
cd "/Users/Ariel/開發中APP/LuckLab"
firebase deploy --only firestore:rules
```

### 8.4 看 Firestore
確認有這兩個 collection：

```text
subscription_events
subscription_status
```

### 8.5 驗證資料
至少確認：
- `subscription_events/{eventId}` 有寫入
- `subscription_status/{uid}` 有更新
- `latestEventType` 正確
- `planId` 可正確對應 `monthly` / `yearly`

## 9. 重新部署常用指令

### 只更新程式碼

```bash
cd "/Users/Ariel/開發中APP/LuckLab"
firebase deploy --only functions:revenueCatWebhook
```

### 更新 secret 後重新部署

```bash
cd "/Users/Ariel/開發中APP/LuckLab"
firebase functions:secrets:set REVENUECAT_WEBHOOK_AUTH
firebase functions:secrets:set REVENUECAT_SECRET_API_KEY
firebase deploy --only functions:revenueCatWebhook
```

### 看最近 log

```bash
cd "/Users/Ariel/開發中APP/LuckLab"
firebase functions:log --only revenueCatWebhook
```

## 10. 常見問題

### `Permission denied` 或 API 未啟用
去 Google Cloud Console 啟用：
- Cloud Functions API
- Cloud Build API
- Artifact Registry API
- Secret Manager API

### 找不到 project
先跑：

```bash
firebase projects:list
firebase use --add
```

### Secret 讀不到
確認：
- 你有先執行 `firebase functions:secrets:set REVENUECAT_WEBHOOK_AUTH`
- function 有重新部署
- RevenueCat 送出的 Authorization 與 secret 一致

### RevenueCat 打 webhook 回 401
確認 RevenueCat Authorization 填的是：

```text
Bearer your_webhook_bearer_token
```

不要多空格，不要少 `Bearer`
