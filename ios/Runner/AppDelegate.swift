import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private static var pendingDeepLinkProductId: String?
  private static var pendingDeepLinkContentItemId: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    let deepLinkChannel = FlutterMethodChannel(name: "com.onepop.deeplink", binaryMessenger: controller.binaryMessenger)
    deepLinkChannel.setMethodCallHandler { call, result in
      if call.method == "getPendingDeepLink" {
        let productId = AppDelegate.pendingDeepLinkProductId ?? ""
        let contentItemId = AppDelegate.pendingDeepLinkContentItemId ?? ""
        AppDelegate.pendingDeepLinkProductId = nil
        AppDelegate.pendingDeepLinkContentItemId = nil
        result(["productId": productId, "contentItemId": contentItemId])
      } else {
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
        result(SharedDataManager.todayCompletedItems())
      case "cleanupOldData":
        SharedDataManager.cleanupOldData()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // ✅ 設定前景通知顯示（讓 App 在前景時也能顯示橫幅通知）
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if url.scheme == "onepop", url.host == "open" {
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
      let productId = components?.queryItems?.first(where: { $0.name == "productId" })?.value ?? ""
      let contentItemId = components?.queryItems?.first(where: { $0.name == "contentItemId" })?.value ?? ""
      AppDelegate.pendingDeepLinkProductId = productId
      AppDelegate.pendingDeepLinkContentItemId = contentItemId
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
    // ✅ 讓 Flutter 處理通知響應
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}
