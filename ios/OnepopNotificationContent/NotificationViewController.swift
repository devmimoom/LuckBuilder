//
//  NotificationViewController.swift
//  OnepopNotificationContent
//

import UIKit
import UserNotifications
import UserNotificationsUI

/// OnePop Notification Content Extension — 展開後自訂 UI（分類、正文、深度解析、來源、按鈕）
/// 色彩與 app_themes.dart 的 Amber Night / Warm Amber 一致。
final class NotificationViewController: UIViewController, UNNotificationContentExtension {

    // MARK: - Theme (aligned with App Amber Night / Warm Amber)
    private struct ThemeColors {
        let background: UIColor
        let cardBackground: UIColor
        let primary: UIColor
        let textPrimary: UIColor
        let textSecondary: UIColor
        let textMuted: UIColor
        let separator: UIColor

        static func forStyle(_ style: UIUserInterfaceStyle) -> ThemeColors {
            switch style {
            case .dark:
                return ThemeColors(
                    background: UIColor(red: 0x0C/255, green: 0x0F/255, blue: 0x1A/255, alpha: 1),
                    cardBackground: UIColor(red: 0x15/255, green: 0x19/255, blue: 0x29/255, alpha: 1),
                    primary: UIColor(red: 0xE8/255, green: 0xA8/255, blue: 0x38/255, alpha: 1),
                    textPrimary: UIColor(red: 0xED/255, green: 0xE8/255, blue: 0xDD/255, alpha: 1),
                    textSecondary: UIColor(red: 0x9A/255, green: 0x94/255, blue: 0x84/255, alpha: 1),
                    textMuted: UIColor(red: 0x6B/255, green: 0x65/255, blue: 0x58/255, alpha: 1),
                    separator: UIColor(red: 232/255, green: 168/255, blue: 56/255, alpha: 0.2)
                )
            default:
                return ThemeColors(
                    background: UIColor(red: 0xFA/255, green: 0xF8/255, blue: 0xF4/255, alpha: 1),
                    cardBackground: UIColor(red: 1, green: 1, blue: 1, alpha: 1),
                    primary: UIColor(red: 0xC8/255, green: 0x85/255, blue: 0x0A/255, alpha: 1),
                    textPrimary: UIColor(red: 0x1A/255, green: 0x17/255, blue: 0x10/255, alpha: 1),
                    textSecondary: UIColor(red: 0x6B/255, green: 0x61/255, blue: 0x52/255, alpha: 1),
                    textMuted: UIColor(red: 0x9A/255, green: 0x90/255, blue: 0x80/255, alpha: 1),
                    separator: UIColor(red: 26/255, green: 23/255, blue: 16/255, alpha: 0.08)
                )
            }
        }
    }

    private let cornerRadius: CGFloat = 12
    private let padding: CGFloat = 16
    private let cardCornerRadius: CGFloat = 18
    private let cardInset: CGFloat = 14

    // MARK: - UI
    private let scrollView = UIScrollView()
    private let cardContainerView = UIView()
    private let stackView = UIStackView()
    // Optional brand header (small OnePop label)
    private let brandLabel = UILabel()
    // Hero header (data only, not in layout)
    private let heroContainerView = UIView()
    private let heroTitleLabel = UILabel()
    private let heroSubtitleLabel = UILabel()
    // Content
    private let categoryLabel = UILabel()
    private let contentLabel = UILabel()
    private let deepAnalysisTitleLabel = UILabel()
    private let deepAnalysisLabel = UILabel()
    private let sourceLabel = UILabel()
    private let separatorLine = UIView()
    private let buttonStack = UIStackView()
    private let openAppButton = UIButton(type: .system)

    // MARK: - Data (from userInfo)
    private var itemId: String = ""
    private var productId: String = ""
    private var contentItemId: String = ""
    private var contentBodyText: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        setupButtons()
        applyTheme()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            applyTheme()
        }
    }

    func didReceive(_ notification: UNNotification) {
        let raw = notification.request.content.userInfo
        var merged = [String: Any]()
        for (k, v) in raw { merged["\(k)"] = v }
        // flutter_local_notifications 常把 payload 放在 userInfo["payload"]（JSON 字串或已解析的 Dictionary），解析後合併
        if let payloadStr = raw["payload"] as? String,
           let data = payloadStr.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for (k, v) in parsed { merged[k] = v }
        } else if let payloadDict = raw["payload"] as? [String: Any] {
            for (k, v) in payloadDict { merged[k] = v }
        }

        itemId = (merged["itemId"] as? String) ?? (merged["contentItemId"] as? String) ?? ""
        contentItemId = (merged["contentItemId"] as? String) ?? itemId
        productId = (merged["productId"] as? String) ?? ""

        let lang = (merged["lang"] as? String) ?? "zh-TW"
        let isEn = (lang == "en")

        let productTitleZh = (merged["productTitle_zh"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let productTitleEn = (merged["productTitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let heroTitleFromPayload = (merged["heroTitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let heroSubtitleFromPayload = (merged["heroSubtitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let contentZh = (merged["content_zh"] as? String) ?? ""
        let contentEn = (merged["content"] as? String) ?? ""
        let contentBody = isEn ? (contentEn.isEmpty ? contentZh : contentEn) : contentZh
        let baseProductTitle = isEn ? (productTitleEn.isEmpty ? productTitleZh : productTitleEn) : productTitleZh

        // Hero header：title + subtitle（與橫幅一致）；目前不顯示卡片，但保留資料以便未來使用
        let heroTitle = (heroTitleFromPayload?.isEmpty == false ? heroTitleFromPayload! : baseProductTitle)
        heroTitleLabel.text = heroTitle.isEmpty ? "OnePop" : heroTitle
        if let heroSubtitleFromPayload, !heroSubtitleFromPayload.isEmpty {
            heroSubtitleLabel.text = heroSubtitleFromPayload
        } else {
            heroSubtitleLabel.text = nil
        }

        // 顶部分類膠囊區塊已從版面移除，不再顯示 categoryLabel
        categoryLabel.text = nil
        categoryLabel.isHidden = true

        contentBodyText = contentBody
        // 深度解析區塊已從版面移除，不再顯示 deepAnalysisLabel
        deepAnalysisLabel.attributedText = nil
        deepAnalysisLabel.isHidden = true
        if baseProductTitle.isEmpty {
            sourceLabel.text = ""
        } else if isEn {
            sourceLabel.text = "— From \u{201C}\(baseProductTitle)\u{201D}"
        } else {
            sourceLabel.text = "— 節選自《\(baseProductTitle)》"
        }
        sourceLabel.isHidden = sourceLabel.text?.isEmpty ?? true

        // 不再顯示「Deep dive / 深度解析」標題，僅保留內文區塊
        deepAnalysisTitleLabel.text = ""
        deepAnalysisTitleLabel.isHidden = true
        openAppButton.setTitle(isEn ? "View full content" : "查看完整內容", for: .normal)

        applyTheme()
    }

    func didReceive(
        _ response: UNNotificationResponse,
        completionHandler completion: @escaping (UNNotificationContentExtensionResponseOption) -> Void
    ) {
        // iOS 系統 action「Done」：轉發給主 App（不主動開啟 App UI）
        if response.actionIdentifier == "ACTION_LEARNED" {
            let doneId = itemId.isEmpty ? contentItemId : itemId
            if !doneId.isEmpty {
                SharedDataManager.markCompleted(itemId: doneId) // fallback
            }
            completion(.dismissAndForwardAction)
            return
        }
        completion(.doNotDismiss)
    }

    // MARK: - Layout
    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        cardContainerView.translatesAutoresizingMaskIntoConstraints = false
        cardContainerView.layer.cornerRadius = cardCornerRadius
        cardContainerView.clipsToBounds = true
        scrollView.addSubview(cardContainerView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 14
        stackView.alignment = .fill
        cardContainerView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            cardContainerView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: cardInset),
            cardContainerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: cardInset),
            cardContainerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -cardInset),
            cardContainerView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -cardInset),
            cardContainerView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -cardInset * 2),
            stackView.topAnchor.constraint(equalTo: cardContainerView.topAnchor, constant: padding),
            stackView.leadingAnchor.constraint(equalTo: cardContainerView.leadingAnchor, constant: padding),
            stackView.trailingAnchor.constraint(equalTo: cardContainerView.trailingAnchor, constant: -padding),
            stackView.bottomAnchor.constraint(equalTo: cardContainerView.bottomAnchor, constant: -padding)
        ])

        brandLabel.text = "OnePop"
        brandLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        brandLabel.adjustsFontForContentSizeCategory = true
        brandLabel.numberOfLines = 1
        stackView.addArrangedSubview(brandLabel)

        contentLabel.font = UIFont.preferredFont(forTextStyle: .body)
        contentLabel.adjustsFontForContentSizeCategory = true
        contentLabel.numberOfLines = 0
        contentLabel.lineBreakMode = .byWordWrapping
        stackView.addArrangedSubview(contentLabel)

        let footnoteSize = UIFont.preferredFont(forTextStyle: .footnote).pointSize
        sourceLabel.font = UIFont.italicSystemFont(ofSize: footnoteSize)
        sourceLabel.numberOfLines = 1
        sourceLabel.lineBreakMode = .byTruncatingTail
        stackView.addArrangedSubview(sourceLabel)

        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        separatorLine.heightAnchor.constraint(equalToConstant: 1).isActive = true
        stackView.addArrangedSubview(separatorLine)

        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fill
        // 方向 B：Done 使用系統通知 action（位於通知底部），避免自訂按鈕語意混淆
        buttonStack.addArrangedSubview(openAppButton)
        stackView.addArrangedSubview(buttonStack)
    }

    private func setupButtons() {
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        openAppButton.setTitle("查看完整內容", for: .normal)
        openAppButton.titleLabel?.font = baseFont
        openAppButton.backgroundColor = .clear
        openAppButton.layer.cornerRadius = cornerRadius
        openAppButton.layer.borderWidth = 1
        openAppButton.clipsToBounds = true
        openAppButton.translatesAutoresizingMaskIntoConstraints = false
        openAppButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        openAppButton.addTarget(self, action: #selector(didTapOpenApp), for: .touchUpInside)
    }

    // MARK: - Theme
    private func applyTheme() {
        let t = ThemeColors.forStyle(traitCollection.userInterfaceStyle)
        view.backgroundColor = t.background
        cardContainerView.backgroundColor = t.cardBackground

        brandLabel.textColor = t.textMuted

        if !contentBodyText.isEmpty {
            let contentFont = contentLabel.font ?? UIFont.preferredFont(forTextStyle: .body)
            let para = NSMutableParagraphStyle()
            para.lineSpacing = 8
            contentLabel.attributedText = NSAttributedString(
                string: contentBodyText,
                attributes: [
                    .font: contentFont,
                    .foregroundColor: t.textPrimary,
                    .paragraphStyle: para
                ]
            )
        }

        sourceLabel.textColor = t.textSecondary
        separatorLine.backgroundColor = t.separator

        openAppButton.setTitleColor(t.primary, for: .normal)
        openAppButton.layer.borderColor = t.primary.cgColor
    }

    @objc private func didTapOpenApp() {
        let cid = contentItemId.isEmpty ? itemId : contentItemId
        SharedDataManager.savePendingDeepLink(productId: productId, contentItemId: cid)
        var components = URLComponents(string: "onepop://open")!
        components.queryItems = [
            URLQueryItem(name: "productId", value: productId),
            URLQueryItem(name: "contentItemId", value: cid)
        ]
        guard let url = components.url else { return }
        extensionContext?.open(url)
    }
}

// MARK: - SharedDataManager (App Groups)
private enum SharedDataManager {
    static let suiteName = "group.com.onepop.shared"
    private static let completedFileName = "extension_completed_today.json"

    static func markCompleted(itemId: String) {
        // 1) UserDefaults（保留，供日後若有修復時相容）
        if let defaults = UserDefaults(suiteName: suiteName) {
            let key = "completed_\(itemId)"
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            defaults.set(formatter.string(from: Date()), forKey: key)
            defaults.synchronize()
        }
        // 2) 寫入 App Group 檔案，避免主 App 讀 UserDefaults 時觸發 CFPrefs 錯誤
        writeCompletedToFile(itemId: itemId)
    }

    private static func writeCompletedToFile(itemId: String) {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) else {
            #if DEBUG
            print("✅ [ExtDone] Extension: containerURL nil for suite=\(suiteName)")
            #endif
            return
        }
        let fileURL = container.appendingPathComponent(completedFileName)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let todayString = formatter.string(from: today)

        var itemIds: [String] = [itemId]
        if FileManager.default.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let date = json["date"] as? String,
           let existing = json["itemIds"] as? [String] {
            if date == todayString {
                var set = Set(existing)
                set.insert(itemId)
                itemIds = Array(set)
            }
        }

        let payload: [String: Any] = ["date": todayString, "itemIds": itemIds]
        guard let out = try? JSONSerialization.data(withJSONObject: payload) else {
            #if DEBUG
            print("✅ [ExtDone] Extension: JSONSerialization failed")
            #endif
            return
        }
        do {
            try out.write(to: fileURL)
            #if DEBUG
            print("✅ [ExtDone] Extension: wrote file path=\(fileURL.path), itemIds=\(itemIds)")
            #endif
        } catch {
            #if DEBUG
            print("✅ [ExtDone] Extension: write failed \(error)")
            #endif
        }
    }

    /// 寫入「查看完整內容」pending deep link，主 App resume 時從 App Group 讀取（溫啟動時 application:open:url 常未被呼叫）
    static func savePendingDeepLink(productId: String, contentItemId: String) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set(productId, forKey: "pendingDeepLink_productId")
        defaults.set(contentItemId, forKey: "pendingDeepLink_contentItemId")
        defaults.synchronize()
    }
}
