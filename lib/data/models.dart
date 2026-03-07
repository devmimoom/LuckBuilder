import '../localization/app_language.dart';

class Segment {
  final String id;
  final String title;
  final String? titleZh;
  final int order;
  final String mode; // "all" | "tag"
  final String? tag;
  final bool published;

  Segment({
    required this.id,
    required this.title,
    this.titleZh,
    required this.order,
    required this.mode,
    required this.published,
    this.tag,
  });

  factory Segment.fromMap(Map<String, dynamic> m) => Segment(
        id: m['id'] ?? '',
        title: m['title'] ?? '',
        titleZh: m['titleZh']?.toString() ?? m['title_zh']?.toString(),
        order: (m['order'] ?? 0) as int,
        mode: m['mode'] ?? 'all',
        tag: m['tag'],
        published: (m['published'] ?? true) as bool,
      );
}

extension SegmentDisplay on Segment {
  String displayTitle(AppLanguage lang) {
    if (lang == AppLanguage.zhTw && titleZh != null && titleZh!.isNotEmpty) return titleZh!;
    return title;
  }
}

class Topic {
  final String id;
  final String title;
  final String? titleZh;
  final bool published;
  final int order;
  final List<String> tags;
  final String? bubbleImageUrl;

  Topic({
    required this.id,
    required this.title,
    this.titleZh,
    required this.published,
    required this.order,
    required this.tags,
    this.bubbleImageUrl,
  });

  factory Topic.fromDoc(String id, Map<String, dynamic> m) => Topic(
        id: id,
        title: m['title'] ?? '',
        titleZh: m['titleZh']?.toString() ?? m['title_zh']?.toString(),
        published: (m['published'] ?? true) as bool,
        order: (m['order'] ?? 0) as int,
        tags: List<String>.from(m['tags'] ?? const []),
        bubbleImageUrl: m['bubbleImageUrl'],
      );
}

extension TopicDisplay on Topic {
  String displayTitle(AppLanguage lang) {
    if (lang == AppLanguage.zhTw && titleZh != null && titleZh!.isNotEmpty) return titleZh!;
    return title;
  }
}

/// 精選清單內的單一項目（如 home banner 一則橫幅），可帶專用 itemImageUrl
class FeaturedListItem {
  final String itemId;
  final String? itemTitle;
  final String? itemTitleZh;
  final String? itemImageUrl;
  final int itemOrder;
  final String type;
  final List<String> productIds;
  final List<String> topicIds;

  FeaturedListItem({
    required this.itemId,
    this.itemTitle,
    this.itemTitleZh,
    this.itemImageUrl,
    this.itemOrder = 0,
    this.type = 'productIds',
    this.productIds = const [],
    this.topicIds = const [],
  });

  static FeaturedListItem? fromMap(dynamic v) {
    if (v is! Map<String, dynamic>) return null;
    final m = v;
    final ftype = (m['type'] ?? 'productIds').toString();
    return FeaturedListItem(
      itemId: (m['itemId'] ?? '').toString(),
      itemTitle: m['itemTitle']?.toString(),
      itemTitleZh: m['itemTitleZh']?.toString(),
      itemImageUrl: m['itemImageUrl']?.toString(),
      itemOrder: (m['itemOrder'] is int) ? m['itemOrder'] as int : int.tryParse(m['itemOrder']?.toString() ?? '0') ?? 0,
      type: ftype,
      productIds: List<String>.from(m['productIds'] ?? const []),
      topicIds: List<String>.from(m['topicIds'] ?? const []),
    );
  }
}

/// 首頁橫幅顯示用：優先使用 itemImageUrl，沒有則用 leadingProduct.coverImageUrl；一張圖可對應多個產品
class BannerItem {
  final String? imageUrl;
  final String? titleOverride;
  final String? titleZhOverride;
  final List<Product> products;

  BannerItem({
    required this.products,
    this.imageUrl,
    this.titleOverride,
    this.titleZhOverride,
  });

  /// 用於標題、封面後備等顯示；空列表時為 null（不應出現，repository 不建空 BannerItem）
  Product? get leadingProduct =>
      products.isNotEmpty ? products.first : null;
}

class FeaturedList {
  final String id;
  final String title;
  final bool published;
  final int order;
  final List<String> productIds;
  final List<String>? topicIds;
  final String? coverImageUrl;
  final String? coverStorageFile;
  final List<FeaturedListItem> items;

  FeaturedList({
    required this.id,
    required this.title,
    required this.published,
    required this.order,
    required this.productIds,
    this.topicIds,
    this.coverImageUrl,
    this.coverStorageFile,
    this.items = const [],
  });

  factory FeaturedList.fromDoc(String id, Map<String, dynamic> m) {
    final rawItems = m['items'];
    final List<FeaturedListItem> items = [];
    if (rawItems is List) {
      for (final e in rawItems) {
        final item = FeaturedListItem.fromMap(e);
        if (item != null && item.itemId.isNotEmpty) items.add(item);
      }
      items.sort((a, b) => a.itemOrder.compareTo(b.itemOrder));
    }
    return FeaturedList(
      id: id,
      title: m['title'] ?? '',
      published: (m['published'] ?? true) as bool,
      order: (m['order'] ?? 0) as int,
      productIds: List<String>.from(m['productIds'] ?? const []),
      topicIds: m['topicIds'] != null
          ? List<String>.from(m['topicIds'] as List)
          : null,
      coverImageUrl: m['coverImageUrl']?.toString(),
      coverStorageFile: m['coverStorageFile']?.toString(),
      items: items,
    );
  }
}

class Product {
  final String id;
  final String title;
  // 雙語欄位（若未提供則為 null）
  final String? titleZh;
  final String? titleEn;
  final String topicId;
  final String level;
  final bool published;

  final String? coverImageUrl;
  final String? levelGoal;
  final String? levelGoalZh;
  final String? levelGoalEn;
  final String? levelBenefit;
  final String? levelBenefitZh;
  final String? levelBenefitEn;

  final String? spec1Label;
  final String? spec2Label;
  final String? spec3Label;
  final String? spec4Label;
  final String? spec1LabelZh;
  final String? spec2LabelZh;
  final String? spec3LabelZh;
  final String? spec4LabelZh;

  final int trialLimit;
  final int? releaseAtMs;
  final int? createdAtMs;
  final String? contentArchitecture;
  final String? contentArchitectureZh;
  final String? contentArchitectureEn;
  /// 解鎖所需額度：0=免費，1=1 額度，2+=多額度
  final int creditsRequired;

  Product({
    required this.id,
    required this.title,
    this.titleZh,
    this.titleEn,
    required this.topicId,
    required this.level,
    required this.published,
    this.coverImageUrl,
    this.levelGoal,
    this.levelGoalZh,
    this.levelGoalEn,
    this.levelBenefit,
    this.levelBenefitZh,
    this.levelBenefitEn,
    this.spec1Label,
    this.spec2Label,
    this.spec3Label,
    this.spec4Label,
    this.spec1LabelZh,
    this.spec2LabelZh,
    this.spec3LabelZh,
    this.spec4LabelZh,
    required this.trialLimit,
    this.releaseAtMs,
    this.createdAtMs,
    this.contentArchitecture,
    this.contentArchitectureZh,
    this.contentArchitectureEn,
    this.creditsRequired = 1,
  });

  factory Product.fromDoc(String id, Map<String, dynamic> m) => Product(
        id: id,
        // 既有欄位仍以 title 儲存主要語言（多數情況為繁中），雙語欄位另外存放
        title: m['title'] ?? '',
        titleZh: m['titleZh']?.toString() ?? m['title_zh']?.toString(),
        titleEn: m['titleEn']?.toString() ?? m['title_en']?.toString(),
        topicId: m['topicId'] ?? '',
        level: m['level'] ?? 'L1',
        published: (m['published'] ?? true) as bool,
        coverImageUrl: m['coverImageUrl'],
        levelGoal: m['levelGoal'],
        levelGoalZh: m['levelGoalZh']?.toString() ?? m['levelGoal_zh']?.toString(),
        levelGoalEn: m['levelGoalEn']?.toString() ?? m['levelGoal_en']?.toString(),
        levelBenefit: m['levelBenefit'],
        levelBenefitZh: m['levelBenefitZh']?.toString() ?? m['levelBenefit_zh']?.toString(),
        levelBenefitEn: m['levelBenefitEn']?.toString() ?? m['levelBenefit_en']?.toString(),
        spec1Label: m['spec1Label'],
        spec2Label: m['spec2Label'],
        spec3Label: m['spec3Label'],
        spec4Label: m['spec4Label'],
        spec1LabelZh: m['spec1LabelZh']?.toString() ?? m['spec1Label_zh']?.toString(),
        spec2LabelZh: m['spec2LabelZh']?.toString() ?? m['spec2Label_zh']?.toString(),
        spec3LabelZh: m['spec3LabelZh']?.toString() ?? m['spec3Label_zh']?.toString(),
        spec4LabelZh: m['spec4LabelZh']?.toString() ?? m['spec4Label_zh']?.toString(),
        trialLimit: (m['trialLimit'] ?? 3) as int,
        releaseAtMs: (m['releaseAtMs'] is num)
            ? (m['releaseAtMs'] as num).toInt()
            : null,
        createdAtMs: (m['createdAtMs'] is num)
            ? (m['createdAtMs'] as num).toInt()
            : null,
        contentArchitecture: (m['contentArchitecture'] ?? m['contentarchitecture']) as String?,
        contentArchitectureZh: m['contentArchitectureZh']?.toString() ?? m['contentArchitecture_zh']?.toString() ?? m['contentarchitecture_zh']?.toString(),
        contentArchitectureEn: m['contentArchitectureEn']?.toString() ?? m['contentArchitecture_en']?.toString() ?? m['contentarchitecture_en']?.toString(),
        creditsRequired: (m['creditsRequired'] is num)
            ? (m['creditsRequired'] as num).toInt().clamp(0, 999)
            : 1,
      );

  DateTime? get releaseAt =>
      releaseAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(releaseAtMs!);

  DateTime? get createdAt =>
      createdAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(createdAtMs!);
}

extension ProductDisplay on Product {
  String? displaySpec1Label(AppLanguage lang) {
    if (lang == AppLanguage.zhTw && spec1LabelZh != null && spec1LabelZh!.isNotEmpty) return spec1LabelZh;
    return spec1Label;
  }
  String? displaySpec2Label(AppLanguage lang) {
    if (lang == AppLanguage.zhTw && spec2LabelZh != null && spec2LabelZh!.isNotEmpty) return spec2LabelZh;
    return spec2Label;
  }
  String? displaySpec3Label(AppLanguage lang) {
    if (lang == AppLanguage.zhTw && spec3LabelZh != null && spec3LabelZh!.isNotEmpty) return spec3LabelZh;
    return spec3Label;
  }
  String? displaySpec4Label(AppLanguage lang) {
    if (lang == AppLanguage.zhTw && spec4LabelZh != null && spec4LabelZh!.isNotEmpty) return spec4LabelZh;
    return spec4Label;
  }
}

class ContentItem {
  final String id;
  final String productId;
  final String anchor;
  final String? anchorZh;
  final String? anchorEn;
  final String content;
  final String? contentZh;
  final String? contentEn;
  final String intent;
  final String? intentZh;
  final String? intentEn;
  final int difficulty;
  final int seq;
  final bool isPreview;
  final String deepAnalysis;
  final String? deepAnalysisZh;
  final String? deepAnalysisEn;

  ContentItem({
    required this.id,
    required this.productId,
    required this.anchor,
    this.anchorZh,
    this.anchorEn,
    required this.content,
    this.contentZh,
    this.contentEn,
    required this.intent,
    this.intentZh,
    this.intentEn,
    required this.difficulty,
    required this.seq,
    required this.isPreview,
    this.deepAnalysis = '',
    this.deepAnalysisZh,
    this.deepAnalysisEn,
  });

  factory ContentItem.fromDoc(String id, Map<String, dynamic> m) => ContentItem(
        id: id,
        productId: m['productId'] ?? '',
        anchor: m['anchor'] ?? '',
        anchorZh: m['anchorZh']?.toString() ?? m['anchor_zh']?.toString(),
        anchorEn: m['anchorEn']?.toString() ?? m['anchor_en']?.toString(),
        content: m['content'] ?? '',
        contentZh: m['contentZh']?.toString() ?? m['content_zh']?.toString(),
        contentEn: m['contentEn']?.toString() ?? m['content_en']?.toString(),
        intent: m['intent'] ?? '',
        intentZh: m['intentZh']?.toString() ?? m['intent_zh']?.toString(),
        intentEn: m['intentEn']?.toString() ?? m['intent_en']?.toString(),
        difficulty: (m['difficulty'] ?? 1) as int,
        seq: (m['seq'] ?? 0) as int,
        isPreview: (m['isPreview'] ?? false) as bool,
        deepAnalysis: (m['deepAnalysis'] ?? '') as String,
        deepAnalysisZh: m['deepAnalysisZh']?.toString() ?? m['deepAnalysis_zh']?.toString(),
        deepAnalysisEn: m['deepAnalysisEn']?.toString() ?? m['deepAnalysis_en']?.toString(),
      );
}

extension ContentItemDisplayLang on ContentItem {
  String displayIntent(AppLanguage lang) {
    if (lang == AppLanguage.zhTw && intentZh != null && intentZh!.isNotEmpty) return intentZh!;
    if (lang == AppLanguage.en && intentEn != null && intentEn!.isNotEmpty) return intentEn!;
    return intent;
  }
}
