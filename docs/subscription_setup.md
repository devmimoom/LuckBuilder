# LuckLab 訂閱上線設定

本文件對應目前 App 端實作，作為 `App Store Connect`、`RevenueCat`、`Firebase` 的單一設定來源。

## 產品結構

### App Store Connect
- Subscription Group: `LuckLab Premium`
- Level: `月訂`、`年訂`、`週訂` 全部放在同一個 level
- 商品 ID:
  - `lucklab_premium_monthly`
  - `lucklab_premium_yearly`
  - `lucklab_premium_weekly`

### RevenueCat
- Entitlement:
  - `premium`
- Current Offering:
  - `$rc_monthly` -> `lucklab_premium_monthly`
  - `$rc_annual` -> `lucklab_premium_yearly`
  - `$rc_weekly` -> `lucklab_premium_weekly`
- Restore behavior:
  - `Transfer to new App User ID`

## 正式 paywall 規則
- 主 paywall 只顯示 `年訂`、`月訂`
- `年訂` 為預設選項與主推方案
- `週訂` 保留在 RevenueCat 與 App Store，供後續實驗頁使用
- 不使用 App Store free trial，免費體驗由 App 內登入後次數邏輯負責

## iOS 方案切換規則
因 `月訂` 與 `年訂` 在同一個 subscription group、同一個 level：
- `月 -> 年`：通常於下次續訂日生效
- `年 -> 月`：通常於下次續訂日生效
- App 內需明確提示「實際生效時間以 App Store 為準」

## App 端環境變數
`.env` 需提供：

```env
REVENUECAT_IOS_API_KEY=your_public_sdk_key
REVENUECAT_ANDROID_API_KEY=optional_for_future
REVENUECAT_ENTITLEMENT_ID=premium
```

## Firebase Functions Secret
部署 webhook 前，需在 Firebase Secret Manager 設定：

```bash
REVENUECAT_WEBHOOK_AUTH=your_webhook_bearer_token
REVENUECAT_SECRET_API_KEY=your_revenuecat_secret_api_key
```

RevenueCat webhook Authorization 建議填：

```text
Bearer your_webhook_bearer_token
```

## RevenueCat Webhook
- Endpoint: `https://<region>-<project>.cloudfunctions.net/revenueCatWebhook`
- 建議監聽事件：
  - `INITIAL_PURCHASE`
  - `RENEWAL`
  - `PRODUCT_CHANGE`
  - `CANCELLATION`
  - `UNCANCELLATION`
  - `BILLING_ISSUE`
  - `EXPIRATION`
  - `TRANSFER`

## Firestore Collections
- `subscription_status/{uid}`
- `subscription_events/{eventId}`

## Firestore 安全規則
- `subscription_status/{uid}`：僅該登入使用者可讀，客戶端不可寫
- `subscription_events/{eventId}`：客戶端不可讀不可寫

## Firebase 部署清單
- 完整部署指令與逐步設定請見：
  - `docs/firebase_functions_deploy.md`

## 驗收重點
- Firebase 登入後 RevenueCat `App User ID` 與 `uid` 一致
- 主 paywall 只顯示月訂與年訂
- 已訂閱者可在 App 內看到目前方案、續訂狀態、到期時間與 `管理訂閱`
- `恢復購買` 可在重裝或換裝置後恢復權限
- RevenueCat webhook 可把事件與最新狀態寫入 Firestore
- App 端可透過 `syncSubscriptionStatus` 主動向後端同步並讀取 `subscription_status/{uid}`
