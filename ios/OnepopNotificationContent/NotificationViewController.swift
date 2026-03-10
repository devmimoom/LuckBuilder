//
//  NotificationViewController.swift
//  OnepopNotificationContent
//

import UIKit
import UserNotifications
import UserNotificationsUI

/// OnePop Notification Content Extension — 展開後自訂 UI（分類、正文、深度解析、來源、按鈕）
final class NotificationViewController: UIViewController, UNNotificationContentExtension {

    // MARK: - Constants
    private enum Colors {
        static let background = UIColor.systemBackground
        static let gold = UIColor(red: 1, green: 0xD7/255, blue: 0, alpha: 1)
        static let goldDim = UIColor(red: 1, green: 0xD7/255, blue: 0, alpha: 0.5)
        static let goldBg = UIColor(red: 1, green: 0xD7/255, blue: 0, alpha: 0.1)
        static let textPrimary = UIColor.label
        static let textSecondary = UIColor.secondaryLabel
        static let separator = UIColor.separator
    }

    private let cornerRadius: CGFloat = 12
    private let padding: CGFloat = 16

    // MARK: - UI
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    // Hero header
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
    private let doneButton = UIButton(type: .system)
    private let openAppButton = UIButton(type: .system)

    // MARK: - Data (from userInfo)
    private var itemId: String = ""
    private var productId: String = ""
    private var contentItemId: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        // 使用系統背景色（Colors.background），讓展開畫面與系統橫幅更有銜接感，並在亮/暗模式下維持可讀性
        view.backgroundColor = Colors.background
        setupLayout()
        setupButtons()
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

        let topicTitleZh = (merged["topicTitle_zh"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let productTitleZh = (merged["productTitle_zh"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let productTitleEn = (merged["productTitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let heroTitleFromPayload = (merged["heroTitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let heroSubtitleFromPayload = (merged["heroSubtitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let contentZh = (merged["content_zh"] as? String) ?? ""
        let deepZh = (merged["deepAnalysis_zh"] as? String) ?? ""
        let contentEn = (merged["content"] as? String) ?? ""
        let deepEn = (merged["deepAnalysis"] as? String) ?? ""

        let contentBody = isEn ? (contentEn.isEmpty ? contentZh : contentEn) : contentZh
        let deepBody = isEn ? (deepEn.isEmpty ? deepZh : deepEn) : deepZh
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

        let contentPara = NSMutableParagraphStyle()
        contentPara.lineSpacing = 6
        let contentFont = contentLabel.font ?? UIFont.preferredFont(forTextStyle: .title3)
        contentLabel.attributedText = NSAttributedString(
            string: contentBody,
            attributes: [.font: contentFont, .foregroundColor: Colors.textPrimary, .paragraphStyle: contentPara]
        )
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
        doneButton.setTitle(isEn ? "✓ Done" : "✓ 已讀完成", for: .normal)
        openAppButton.setTitle(isEn ? "View full content" : "查看完整內容", for: .normal)
    }

    // MARK: - Layout
    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .fill
        scrollView.addSubview(stackView)

        // 移除 Hero 卡片，僅使用內容 + CTA
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: padding),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: padding),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -padding),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -padding),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -padding * 2)
        ])

        // 分類膠囊區塊已移除，不再加入 stackView
        contentLabel.font = UIFont.preferredFont(forTextStyle: .body)
        contentLabel.adjustsFontForContentSizeCategory = true
        contentLabel.textColor = Colors.textPrimary
        contentLabel.numberOfLines = 0
        contentLabel.lineBreakMode = .byWordWrapping
        stackView.addArrangedSubview(contentLabel)

        // 深度解析 Label 也不再加入 stackView

        let footnoteSize = UIFont.preferredFont(forTextStyle: .footnote).pointSize
        sourceLabel.font = UIFont.italicSystemFont(ofSize: footnoteSize)
        sourceLabel.textColor = Colors.goldDim
        sourceLabel.numberOfLines = 1
        sourceLabel.lineBreakMode = .byTruncatingTail
        stackView.addArrangedSubview(sourceLabel)

        separatorLine.backgroundColor = Colors.separator
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        separatorLine.heightAnchor.constraint(equalToConstant: 1).isActive = true
        stackView.addArrangedSubview(separatorLine)

        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        buttonStack.addArrangedSubview(doneButton)
        buttonStack.addArrangedSubview(openAppButton)
        stackView.addArrangedSubview(buttonStack)
    }

    private func setupButtons() {
        doneButton.setTitle("✓ 已讀完成", for: .normal)
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        doneButton.titleLabel?.font = UIFont.systemFont(ofSize: baseFont.pointSize, weight: .bold)
        doneButton.setTitleColor(Colors.background, for: .normal)
        doneButton.backgroundColor = Colors.gold
        doneButton.layer.cornerRadius = cornerRadius
        doneButton.clipsToBounds = true
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        doneButton.addTarget(self, action: #selector(didTapDone), for: .touchUpInside)

        openAppButton.setTitle("查看完整內容", for: .normal)
        openAppButton.titleLabel?.font = baseFont
        openAppButton.setTitleColor(Colors.gold, for: .normal)
        openAppButton.backgroundColor = .clear
        openAppButton.layer.cornerRadius = cornerRadius
        openAppButton.layer.borderWidth = 1.5
        openAppButton.layer.borderColor = Colors.gold.cgColor
        openAppButton.clipsToBounds = true
        openAppButton.translatesAutoresizingMaskIntoConstraints = false
        openAppButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        openAppButton.addTarget(self, action: #selector(didTapOpenApp), for: .touchUpInside)
    }

    @objc private func didTapDone() {
        guard !itemId.isEmpty else {
            extensionContext?.dismissNotificationContentExtension()
            return
        }
        SharedDataManager.markCompleted(itemId: itemId)
        extensionContext?.dismissNotificationContentExtension()
    }

    @objc private func didTapOpenApp() {
        var components = URLComponents(string: "onepop://open")!
        components.queryItems = [
            URLQueryItem(name: "productId", value: productId),
            URLQueryItem(name: "contentItemId", value: contentItemId.isEmpty ? itemId : contentItemId)
        ]
        guard let url = components.url else { return }
        extensionContext?.open(url)
    }
}

// MARK: - SharedDataManager (App Groups)
private enum SharedDataManager {
    static let suiteName = "group.com.onepop.shared"

    static func markCompleted(itemId: String) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        let key = "completed_\(itemId)"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        defaults.set(formatter.string(from: Date()), forKey: key)
        defaults.synchronize()
    }
}
