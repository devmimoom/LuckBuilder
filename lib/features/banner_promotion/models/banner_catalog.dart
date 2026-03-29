import 'banner_item.dart';

/// 學期縮寫 → 顯示名稱，例：「七上」→「七年級 上學期」
const Map<String, String> kSemesterDisplayNames = {
  '七上': '七年級 上學期',
  '七下': '七年級 下學期',
  '八上': '八年級 上學期',
  '八下': '八年級 下學期',
  '九上': '九年級 上學期',
  '九下': '九年級 下學期',
};

/// 學期縮寫排序權重（越小越前）
const List<String> kSemesterOrder = ['七上', '七下', '八上', '八下', '九上', '九下'];

String semesterDisplayName(String semester) =>
    kSemesterDisplayNames[semester] ?? semester;

class BannerCatalog {
  const BannerCatalog({
    required this.items,
    this.generatedAt,
    this.sourceFile,
    this.sourceSheets,
  });

  final List<BannerItem> items;
  final String? generatedAt;
  final String? sourceFile;
  final List<String>? sourceSheets;

  factory BannerCatalog.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? [];
    return BannerCatalog(
      items: raw
          .map((e) => BannerItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      generatedAt: json['generatedAt'] as String?,
      sourceFile: json['sourceFile'] as String?,
      sourceSheets: (json['sourceSheets'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  /// 取 `segment` 為「國文」的第一則，供橫幅說明區展示（無則為 null）。
  BannerItem? get chineseExampleItem {
    for (final e in items) {
      if (e.segment.trim() == '國文') return e;
    }
    return null;
  }

  List<String> get segments {
    final s = items.map((e) => e.segment).where((x) => x.isNotEmpty).toSet().toList();
    s.sort();
    return s;
  }

  // ── 學期維度 ──────────────────────────────────────────────

  /// 取某科目下已有資料的學期縮寫清單（依 kSemesterOrder 排序）。
  List<String> semestersForSegment(String segment) {
    final s = items
        .where((e) => e.segment == segment && e.semester.isNotEmpty)
        .map((e) => e.semester)
        .toSet()
        .toList();
    s.sort((a, b) {
      final ai = kSemesterOrder.indexOf(a);
      final bi = kSemesterOrder.indexOf(b);
      return (ai == -1 ? 99 : ai).compareTo(bi == -1 ? 99 : bi);
    });
    return s;
  }

  /// 取某科目＋學期下的子科目清單（無子科目時回傳空列表）。
  List<String> subSegmentsFor(String segment, String semester) {
    final s = items
        .where((e) =>
            e.segment == segment &&
            e.semester == semester &&
            e.subSegment.isNotEmpty)
        .map((e) => e.subSegment)
        .toSet()
        .toList();
    s.sort();
    return s;
  }

  /// 取某科目＋學期＋子科目下的 productId 清單。
  /// [subSegment] 為空字串表示不限子科目。
  List<String> productsForSemester(
    String segment,
    String semester, {
    String subSegment = '',
  }) {
    final p = items
        .where((e) =>
            e.segment == segment &&
            e.semester == semester &&
            (subSegment.isEmpty || e.subSegment == subSegment))
        .map((e) => e.productId)
        .where((x) => x.isNotEmpty)
        .toSet()
        .toList();
    p.sort();
    return p;
  }

  // ── 原有 topicId 維度（向下相容）─────────────────────────

  List<int> topicsForSegment(String segment) {
    final t = items.where((e) => e.segment == segment).map((e) => e.topicId).toSet().toList();
    t.sort();
    return t;
  }

  List<String> productsFor(String segment, int topicId) {
    final p = items
        .where((e) => e.segment == segment && e.topicId == topicId)
        .map((e) => e.productId)
        .where((x) => x.isNotEmpty)
        .toSet()
        .toList();
    p.sort();
    return p;
  }

  List<BannerItem> itemsFor(String segment, int topicId, String productId) {
    final list = items
        .where((e) =>
            e.segment == segment &&
            e.topicId == topicId &&
            e.productId == productId)
        .toList();
    list.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return list;
  }

  /// 複選多個 productId 時，合併所有對應項目（依 sortKey 排序）。
  List<BannerItem> itemsForProducts(
    String segment,
    int topicId,
    Set<String> productIds,
  ) {
    if (productIds.isEmpty) return [];
    final list = items
        .where((e) =>
            e.segment == segment &&
            e.topicId == topicId &&
            productIds.contains(e.productId))
        .toList();
    list.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return list;
  }

  /// 依學期＋子科目篩選，複選多個 productId（依 sortKey 排序）。
  List<BannerItem> itemsForProductsBySemester(
    String segment,
    String semester,
    Set<String> productIds, {
    String subSegment = '',
  }) {
    if (productIds.isEmpty) return [];
    final list = items
        .where((e) =>
            e.segment == segment &&
            e.semester == semester &&
            (subSegment.isEmpty || e.subSegment == subSegment) &&
            productIds.contains(e.productId))
        .toList();
    list.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return list;
  }
}
