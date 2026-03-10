import Foundation

/// App Groups 共用資料（與 Notification Content Extension 同步「已讀完成」狀態）
enum SharedDataManager {
    static let suiteName = "group.com.onepop.shared"

    static func markCompleted(itemId: String) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        let key = "completed_\(itemId)"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        defaults.set(formatter.string(from: Date()), forKey: key)
        defaults.synchronize()
    }

    static func isCompleted(itemId: String) -> Bool {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return false }
        return defaults.string(forKey: "completed_\(itemId)") != nil
    }

    /// 回傳「今日」完成過的 itemId 列表（依裝置日曆日）
    static func todayCompletedItems() -> [String] {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return [] }
        let allKeys = defaults.dictionaryRepresentation().keys
        let prefix = "completed_"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var result: [String] = []
        for key in allKeys where key.hasPrefix(prefix) {
            guard let value = defaults.string(forKey: key),
                  let date = formatter.date(from: value) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            if dayStart == today {
                let itemId = String(key.dropFirst(prefix.count))
                result.append(itemId)
            }
        }
        return result
    }

    /// 刪除 7 天前的 completed_ 鍵
    static func cleanupOldData() {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        let prefix = "completed_"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -7, to: Date()) else { return }
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys where key.hasPrefix(prefix) {
            guard let value = defaults.string(forKey: key),
                  let date = formatter.date(from: value), date < cutoff else { continue }
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
    }
}
