import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private static var pendingDeepLinkProductId: String?
  private static var pendingDeepLinkContentItemId: String?
  private static var pendingDoneItemId: String?
  private var deepLinkChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 冷啟動時 URL 可能只出現在 launchOptions 而非 application:open:url
    if let url = launchOptions?[.url] as? URL, url.scheme == "onepop" {
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
      if url.host == "open" {
        let productId = components?.queryItems?.first(where: { $0.name == "productId" })?.value ?? ""
        let contentItemId = components?.queryItems?.first(where: { $0.name == "contentItemId" })?.value ?? ""
        #if DEBUG
        print("🔗 [DeepLink] AppDelegate launchOptions URL: productId=\(productId), contentItemId=\(contentItemId)")
        #endif
        AppDelegate.pendingDeepLinkProductId = productId
        AppDelegate.pendingDeepLinkContentItemId = contentItemId
      }
    }

    GeneratedPluginRegistrant.register(with: self)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    deepLinkChannel = FlutterMethodChannel(name: "com.onepop.deeplink", binaryMessenger: controller.binaryMessenger)
    deepLinkChannel?.setMethodCallHandler { call, result in
      switch call.method {
      case "getPendingDeepLink":
        var productId = AppDelegate.pendingDeepLinkProductId ?? ""
        var contentItemId = AppDelegate.pendingDeepLinkContentItemId ?? ""
        AppDelegate.pendingDeepLinkProductId = nil
        AppDelegate.pendingDeepLinkContentItemId = nil
        if productId.isEmpty && contentItemId.isEmpty, let fromGroup = SharedDataManager.getPendingDeepLinkFromAppGroup() {
          productId = fromGroup.productId
          contentItemId = fromGroup.contentItemId
          SharedDataManager.clearPendingDeepLinkFromAppGroup()
        }
        result(["productId": productId, "contentItemId": contentItemId])
      case "getPendingDoneItemId":
        let itemId = AppDelegate.pendingDoneItemId ?? ""
        AppDelegate.pendingDoneItemId = nil
        result(itemId)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let sharedDataChannel = FlutterMethodChannel(name: "com.onepop.shared_data", binaryMessenger: controller.binaryMessenger)
    sharedDataChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "isCompleted":
        guard let args = call.arguments as? [String: Any],
              let itemId = args["itemId"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "itemId required", details: nil))
          return
        }
        result(SharedDataManager.isCompleted(itemId: itemId))
      case "getTodayCompleted":
        let items = SharedDataManager.todayCompletedItems()
        #if DEBUG
        let diag = SharedDataManager.diagnosticInfo()
        print("✅ [ExtDone] Runner getTodayCompleted: items=\(items), diag=\(diag)")
        #endif
        result(items)
      case "cleanupOldData":
        SharedDataManager.cleanupOldData()
        result(nil)
      case "clearTodayCompletedFile":
        SharedDataManager.clearTodayCompletedFile()
        result(nil)
      case "getDiagnosticInfo":
        result(SharedDataManager.diagnosticInfo())
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // ✅ 設定前景通知顯示（讓 App 在前景時也能顯示橫幅通知）
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    // 冷啟動 fallback：若 Flutter 的 getPendingDoneItemId 查詢未覆蓋到，1.5s 後再推送一次
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
      guard let itemId = AppDelegate.pendingDoneItemId, !itemId.isEmpty else { return }
      AppDelegate.pendingDoneItemId = nil
      #if DEBUG
      print("✅ [ExtDone] cold-start fallback: sending pending doneItemId=\(itemId)")
      #endif
      self?.deepLinkChannel?.invokeMethod("syncExtensionDone", arguments: ["itemId": itemId])
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    guard url.scheme == "onepop" else {
      return super.application(app, open: url, options: options)
    }
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

    if url.host == "open" {
      let productId = components?.queryItems?.first(where: { $0.name == "productId" })?.value ?? ""
      let contentItemId = components?.queryItems?.first(where: { $0.name == "contentItemId" })?.value ?? ""
      #if DEBUG
      print("🔗 [DeepLink] AppDelegate received URL: productId=\(productId), contentItemId=\(contentItemId)")
      #endif
      AppDelegate.pendingDeepLinkProductId = productId
      AppDelegate.pendingDeepLinkContentItemId = contentItemId
      deepLinkChannel?.invokeMethod("checkPendingDeepLink", arguments: nil)
      return true
    }

    return super.application(app, open: url, options: options)
  }

  // ✅ iOS 10+ 前景通知顯示設定
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // 允許在前景顯示通知橫幅、聲音和角標
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  // ✅ 用戶點擊或滑掉通知時的回調
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let category = response.notification.request.content.categoryIdentifier
    let actionId = response.actionIdentifier
    // 僅攔截 Rich Notification 的「Done」action，其他交由 Flutter 插件原流程
    if category == "ONEPOP_DEEP_DIVE", actionId == "ACTION_LEARNED" {
      let userInfo = response.notification.request.content.userInfo
      let itemId = extractOnepopItemId(userInfo: userInfo)
      #if DEBUG
      print("✅ [ExtDone] didReceive action ACTION_LEARNED, category=\(category), itemId=\(itemId)")
      #endif
      if !itemId.isEmpty {
        if deepLinkChannel != nil {
          deepLinkChannel?.invokeMethod("syncExtensionDone", arguments: ["itemId": itemId])
        } else {
          AppDelegate.pendingDoneItemId = itemId
        }
      }
      completionHandler()
      return
    }
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }

  private func extractOnepopItemId(userInfo: [AnyHashable: Any]) -> String {
    if let itemId = userInfo["itemId"] as? String, !itemId.isEmpty {
      return itemId
    }
    if let contentItemId = userInfo["contentItemId"] as? String, !contentItemId.isEmpty {
      return contentItemId
    }
    if let payloadStr = userInfo["payload"] as? String,
       let data = payloadStr.data(using: .utf8),
       let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      if let itemId = payload["itemId"] as? String, !itemId.isEmpty {
        return itemId
      }
      if let contentItemId = payload["contentItemId"] as? String, !contentItemId.isEmpty {
        return contentItemId
      }
    } else if let payload = userInfo["payload"] as? [String: Any] {
      if let itemId = payload["itemId"] as? String, !itemId.isEmpty {
        return itemId
      }
      if let contentItemId = payload["contentItemId"] as? String, !contentItemId.isEmpty {
        return contentItemId
      }
    }
    return ""
  }
}
