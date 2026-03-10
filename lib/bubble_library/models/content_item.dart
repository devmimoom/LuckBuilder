import '../../localization/app_language.dart';

class ContentItem {
  final String id;
  final String productId;
  final String anchorGroup;
  final String anchor;
  final String intent;
  final int difficulty;
  final String content;
  final String sourceUrl; // ; separated
  final int pushOrder; // Day N
  final int seq;
  final int isPreview; // 0/1
  final String deepAnalysis; // 深度解析（來自 Excel deepAnalysis 欄位）
  final String? anchorGroupZh;
  final String? anchorZh;
  final String? contentZh;
  final String? deepAnalysisZh;
  final String? intentZh;
  /// 橫幅標題（英）Firestore pushTitle
  final String? pushTitle;
  /// 橫幅預覽文字（英）Firestore pushTeaser
  final String? pushTeaser;
  /// 橫幅標題（繁中）Firestore pushTitle_zh，6–14 字
  final String? pushTitleZh;
  /// 橫幅預覽文字（繁中）Firestore pushTeaser_zh，17–32 字
  final String? pushTeaserZh;

  const ContentItem({
    required this.id,
    required this.productId,
    required this.anchorGroup,
    required this.anchor,
    required this.intent,
    required this.difficulty,
    required this.content,
    required this.sourceUrl,
    required this.pushOrder,
    required this.seq,
    required this.isPreview,
    required this.deepAnalysis,
    this.anchorGroupZh,
    this.anchorZh,
    this.contentZh,
    this.deepAnalysisZh,
    this.intentZh,
    this.pushTitle,
    this.pushTeaser,
    this.pushTitleZh,
    this.pushTeaserZh,
  });

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  factory ContentItem.fromMap(String id, Map<String, dynamic> m) {
    int isPreviewValue = 0;
    final isPreviewField = m['isPreview'];
    if (isPreviewField is bool) {
      isPreviewValue = isPreviewField ? 1 : 0;
    } else if (isPreviewField is int) {
      isPreviewValue = isPreviewField;
    } else if (isPreviewField != null) {
      isPreviewValue = (isPreviewField as num).toInt();
    }

    int pushOrderValue = 0;
    final pushOrderField = m['pushOrder'];
    if (pushOrderField != null) {
      pushOrderValue = (pushOrderField as num).toInt();
    }

    return ContentItem(
      id: id,
      productId: (m['productId'] ?? '') as String,
      anchorGroup: (m['anchorGroup'] ?? '') as String,
      anchor: (m['anchor'] ?? '') as String,
      intent: (m['intent'] ?? '') as String,
      difficulty: (m['difficulty'] ?? 1) as int,
      content: (m['content'] ?? '') as String,
      sourceUrl: (m['sourceUrl'] ?? '') as String,
      pushOrder: pushOrderValue,
      seq: (m['seq'] ?? 0) as int,
      isPreview: isPreviewValue,
      deepAnalysis: (m['deepAnalysis'] ?? '') as String,
      anchorGroupZh: _str(m['anchorGroupZh']) ?? _str(m['anchorGroup_zh']),
      anchorZh: _str(m['anchorZh']) ?? _str(m['anchor_zh']),
      contentZh: _str(m['contentZh']) ?? _str(m['content_zh']),
      deepAnalysisZh: _str(m['deepAnalysisZh']) ?? _str(m['deepAnalysis_zh']),
      intentZh: _str(m['intentZh']) ?? _str(m['intent_zh']),
      pushTitle: _str(m['pushTitle']),
      pushTeaser: _str(m['pushTeaser']),
      pushTitleZh: _str(m['pushTitleZh']) ?? _str(m['pushTitle_zh']),
      pushTeaserZh: _str(m['pushTeaserZh']) ?? _str(m['pushTeaser_zh']),
    );
  }
}

extension ContentItemDisplay on ContentItem {
  String displayAnchorGroup(AppLanguage lang) {
    if (lang == AppLanguage.zhTw && anchorGroupZh != null && anchorGroupZh!.isNotEmpty) return anchorGroupZh!;
    return anchorGroup;
  }

  String displayAnchor(AppLanguage lang) {
    if (lang == AppLanguage.zhTw && anchorZh != null && anchorZh!.isNotEmpty) return anchorZh!;
    return anchor;
  }

  String displayContent(AppLanguage lang) {
    if (lang == AppLanguage.zhTw && contentZh != null && contentZh!.isNotEmpty) return contentZh!;
    return content;
  }

  String displayDeepAnalysis(AppLanguage lang) {
    if (lang == AppLanguage.zhTw && deepAnalysisZh != null && deepAnalysisZh!.isNotEmpty) return deepAnalysisZh!;
    return deepAnalysis;
  }

  String displayIntent(AppLanguage lang) {
    if (lang == AppLanguage.zhTw && intentZh != null && intentZh!.isNotEmpty) return intentZh!;
    return intent;
  }
}
