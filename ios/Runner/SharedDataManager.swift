import Foundation

/// App Groups 共用資料（與 Notification Content Extension 同步「已讀完成」狀態）
/// 主 App 讀取 App Group UserDefaults 會觸發 CFPrefs 錯誤，故「今日完成」改由檔案傳遞
enum SharedDataManager {
    static let suiteName = "group.com.onepop.shared"
    private static let completedFileName = "extension_completed_today.json"

    static func markCompleted(itemId: String) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        let key = "completed_\(itemId)"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        defaults.set(formatter.string(from: Date()), forKey: key)
        defaults.synchronize()
    }

    static func isCompleted(itemId: String) -> Bool {
        return todayCompletedItems().contains(itemId)
    }

    /// 回傳「今日」完成過的 itemId 列表
    /// 策略 1：從 JSON 檔案讀取（Extension writeCompletedToFile）
    /// 策略 2：直接讀取 App Group 的 UserDefaults plist 檔案（繞過 cfprefsd 錯誤）
    static func todayCompletedItems() -> [String] {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) else {
            return []
        }

        // 策略 1：JSON 檔案
        let fileURL = container.appendingPathComponent(completedFileName)
        if FileManager.default.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let date = json["date"] as? String,
           let itemIds = json["itemIds"] as? [String] {
            let todayString = todayDateString()
            if date == todayString && !itemIds.isEmpty {
                return itemIds
            }
        }

        // 策略 2：直接讀取 App Group 的 plist 檔案（繞過 UserDefaults API 的 cfprefsd 錯誤）
        let plistURL = container
            .appendingPathComponent("Library/Preferences")
            .appendingPathComponent("\(suiteName).plist")
        guard FileManager.default.fileExists(atPath: plistURL.path),
              let dict = NSDictionary(contentsOf: plistURL) as? [String: Any] else {
            return []
        }
        let prefix = "completed_"
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var result: [String] = []
        for (key, value) in dict where key.hasPrefix(prefix) {
            guard let dateStr = value as? String,
                  let date = isoFormatter.date(from: dateStr) else { continue }
            if calendar.startOfDay(for: date) == today {
                result.append(String(key.dropFirst(prefix.count)))
            }
        }
        return result
    }

    private static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }

    /// Extension「查看完整內容」寫入的 pending deep link（溫啟動時 application:open:url 常未被呼叫，改由 App Group 傳遞）
    static func getPendingDeepLinkFromAppGroup() -> (productId: String, contentItemId: String)? {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        defaults.synchronize()
        let productId = defaults.string(forKey: "pendingDeepLink_productId") ?? ""
        let contentItemId = defaults.string(forKey: "pendingDeepLink_contentItemId") ?? ""
        if productId.isEmpty && contentItemId.isEmpty { return nil }
        return (productId, contentItemId)
    }

    static func clearPendingDeepLinkFromAppGroup() {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.removeObject(forKey: "pendingDeepLink_productId")
        defaults.removeObject(forKey: "pendingDeepLink_contentItemId")
        defaults.synchronize()
    }

    /// 刪除 7 天前的 completed_ 鍵，並清理非今日的完成檔案
    static func cleanupOldData() {
        if let defaults = UserDefaults(suiteName: suiteName) {
            let prefix = "completed_"
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let calendar = Calendar.current
            if let cutoff = calendar.date(byAdding: .day, value: -7, to: Date()) {
                let allKeys = defaults.dictionaryRepresentation().keys
                for key in allKeys where key.hasPrefix(prefix) {
                    guard let value = defaults.string(forKey: key),
                          let date = formatter.date(from: value), date < cutoff else { continue }
                    defaults.removeObject(forKey: key)
                }
            }
            defaults.synchronize()
        }
        // 刪除非今日的 extension_completed_today.json
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) else { return }
        let fileURL = container.appendingPathComponent(completedFileName)
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let date = json["date"] as? String else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let todayString = formatter.string(from: Date())
        if date != todayString {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// 診斷：列出 App Group container 下的所有檔案，以及完成檔案的內容
    static func diagnosticInfo() -> String {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) else {
            return "container=nil"
        }
        let fileURL = container.appendingPathComponent(completedFileName)
        let jsonExists = FileManager.default.fileExists(atPath: fileURL.path)
        var info = "jsonFile=\(jsonExists)"
        if jsonExists, let data = try? Data(contentsOf: fileURL), let str = String(data: data, encoding: .utf8) {
            info += ", jsonContent=\(str)"
        }
        let plistURL = container
            .appendingPathComponent("Library/Preferences")
            .appendingPathComponent("\(suiteName).plist")
        let plistExists = FileManager.default.fileExists(atPath: plistURL.path)
        info += ", plistFile=\(plistExists)"
        if plistExists, let dict = NSDictionary(contentsOf: plistURL) as? [String: Any] {
            let completedKeys = dict.keys.filter { $0.hasPrefix("completed_") }
            info += ", completedKeys=\(completedKeys)"
            for k in completedKeys {
                info += ", \(k)=\(dict[k] ?? "nil")"
            }
        }
        let prefsDir = container.appendingPathComponent("Library/Preferences")
        let prefsFiles = (try? FileManager.default.contentsOfDirectory(atPath: prefsDir.path)) ?? []
        info += ", prefsFiles=\(prefsFiles)"
        return info
    }

    /// 同步完成後清除今日完成檔案，避免重複處理
    static func clearTodayCompletedFile() {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) else { return }
        let fileURL = container.appendingPathComponent(completedFileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}
