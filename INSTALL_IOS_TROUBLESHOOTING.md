# iOS 安裝到真機排錯

## 若出現「無法驗證其完整性」或 Could not run ... on device

錯誤可能類似：
- `無法安裝此App，因為無法驗證其完整性`
- `Failed to verify code signature of ... objective_c.framework (The executable contains an invalid signature.)`
- `Could not run build/ios/iphoneos/Runner.app on [裝置]. Try launching Xcode...`

**建議做法：用 Xcode 建置並安裝**

1. **用 Xcode 開啟專案**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **選擇你的 iPhone**
   - 上方工具列「Run destination」選你的實機（例如：Josh 的 iPhone），不要選模擬器。

3. **簽章設定**
   - 左側點選 **Runner** 專案 → 選 **Runner** target → 分頁 **Signing & Capabilities**
   - 勾選 **Automatically manage signing**
   - **Team** 選你的 Apple ID 開發者帳號（若沒有可先選「Add an Account」登入）

4. **建置並安裝**
   - 選單 **Product** → **Run**（或按 ⌘R）
   - 等待建置完成，app 會安裝到手機並啟動。

5. **若手機出現「未受信任的開發者」**
   - 手機：**設定** → **一般** → **VPN 與裝置管理**（或「描述檔與裝置管理」）
   - 點你的開發者帳號 → **信任「xxx」**

---

## 指令列安裝（在 Xcode 跑過一次成功後可再試）

```bash
# 清理後再試
flutter clean
flutter run --release -d <你的 iPhone 裝置 ID>
# 裝置 ID 可用 flutter devices 查看
```

若仍失敗，請持續用 **Xcode → Product → Run** 安裝到真機。
