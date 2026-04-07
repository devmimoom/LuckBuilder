# iOS Sandbox 訂閱測試矩陣

本清單對應目前 LuckLab 訂閱架構，用於正式上線前逐項驗證。

## 前置條件
- App Store Connect 已建立：
  - `lucklab_premium_monthly`
  - `lucklab_premium_yearly`
  - `lucklab_premium_weekly`
- 三個商品位於同一個 `Subscription Group`、同一個 level
- RevenueCat `Current Offering` 已對應：
  - `$rc_monthly`
  - `$rc_annual`
  - `$rc_weekly`
- Firebase Auth 可正常登入並取得 `uid`
- RevenueCat webhook 已指向 Firebase Functions `revenueCatWebhook`

## App 端基本驗收
- 未登入打開 paywall：
  - 顯示 `年訂`、`月訂`
  - 不顯示 `週訂`
  - 預設選中 `年訂`
- 登入後打開 paywall：
  - 可看到免費體驗剩餘次數
  - 價格來自 RevenueCat / App Store，而非硬編碼

## 首次購買
### 月訂
- 以新帳號登入
- 在 paywall 選 `月訂`
- 完成沙盒購買
- 驗證：
  - premium 權限立即生效
  - 訂閱狀態顯示 `訂閱有效，將自動續訂`
  - `目前方案` 為 `一月`
  - `管理訂閱` 按鈕可開啟商店頁

### 年訂
- 以另一個新帳號登入
- 在 paywall 選 `年訂`
- 完成沙盒購買
- 驗證：
  - premium 權限立即生效
  - `目前方案` 為 `一年`
  - `年訂` 顯示為主推方案

## 方案切換
### 月訂轉年訂
- 先購買月訂
- 回到 paywall，選 `年訂`
- 發起切換
- 驗證：
  - CTA 顯示為切換文案
  - 成功訊息提示「實際生效時間以 App Store 為準」
  - UI 保留 `管理訂閱`
  - RevenueCat event log 收到 `PRODUCT_CHANGE`

### 年訂轉月訂
- 先購買年訂
- 回到 paywall，選 `月訂`
- 發起切換
- 驗證同上

## 恢復購買
- 使用已購買帳號刪除 App 後重裝
- 重新登入同一 Firebase 帳號
- 點擊 `恢復購買`
- 驗證：
  - premium 權限恢復
  - 目前方案與狀態正確

## 登出 / 換帳號
- A 帳號購買後登出
- 登入 B 帳號
- 點 `恢復購買`
- 因目前設定 `Transfer to new App User ID`
- 驗證：
  - 訂閱會轉移到 B
  - Firestore 收到 `TRANSFER`
  - A 的 `subscription_status` 會標記 `transferredAwayAt`

## 取消續訂
- 從 `管理訂閱` 進入 App Store 沙盒頁取消續訂
- 回 App 後刷新狀態
- 驗證：
  - 若尚未到期，仍有 premium 權限
  - 顯示 `已取消續訂，權限仍有效`
  - 到期日顯示正確

## 付款異常
- 使用沙盒測試情境製造 billing issue
- 驗證：
  - premium 若仍有效，App 顯示付款異常提示
  - `管理訂閱` 可用
  - Firestore `billingIssueDetectedAt` 有值

## 到期失效
- 等待沙盒週期到期或使用對應測試帳號流程
- 驗證：
  - premium 權限移除
  - paywall 顯示恢復為可購買狀態
  - Firestore 收到 `EXPIRATION`

## Webhook 驗收
- `subscription_events/{eventId}` 有完整事件資料
- `subscription_status/{uid}` 有最新聚合狀態
- `planId` 能正確映射 `monthly` / `yearly`
- `latestEventType` 會隨事件更新
