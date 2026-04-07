import 'dart:convert';

class Mistake {
  final int? id;
  final String imagePath;
  final String title;
  final List<String> tags;
  final List<String> solutions;
  final String subject; // 新增：科目 (數學, 英文...)
  final String category; // 新增：分類 (幾何, 文法...)
  final String? chapter; // 章節
  final String? errorReason; // 新增：錯誤原因 (粗心, 觀念不懂...)
  final int reviewCount;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;
  final int masteryLevel;
  final String? errorType;
  final DateTime createdAt;

  Mistake({
    this.id,
    required this.imagePath,
    required this.title,
    required this.tags,
    required this.solutions,
    required this.subject,
    required this.category,
    this.chapter,
    this.errorReason,
    this.reviewCount = 0,
    this.lastReviewedAt,
    this.nextReviewAt,
    this.masteryLevel = 0,
    this.errorType,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'image_path': imagePath,
      'title': title,
      'tags': jsonEncode(tags),
      'solutions': jsonEncode(solutions),
      'subject': subject,
      'category': category,
      'chapter': chapter,
      'error_reason': errorReason,
      'review_count': reviewCount,
      'last_reviewed_at': lastReviewedAt?.millisecondsSinceEpoch,
      'next_review_at': nextReviewAt?.millisecondsSinceEpoch,
      'mastery_level': masteryLevel,
      'error_type': errorType,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  Mistake copyWith({
    int? id,
    String? imagePath,
    String? title,
    List<String>? tags,
    List<String>? solutions,
    String? subject,
    String? category,
    String? chapter,
    String? errorReason,
    int? reviewCount,
    DateTime? lastReviewedAt,
    DateTime? nextReviewAt,
    int? masteryLevel,
    String? errorType,
    DateTime? createdAt,
    bool clearLastReviewedAt = false,
    bool clearNextReviewAt = false,
    bool clearErrorReason = false,
    bool clearErrorType = false,
    bool clearChapter = false,
  }) {
    return Mistake(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      title: title ?? this.title,
      tags: tags ?? this.tags,
      solutions: solutions ?? this.solutions,
      subject: subject ?? this.subject,
      category: category ?? this.category,
      chapter: clearChapter ? null : (chapter ?? this.chapter),
      errorReason: clearErrorReason ? null : (errorReason ?? this.errorReason),
      reviewCount: reviewCount ?? this.reviewCount,
      lastReviewedAt:
          clearLastReviewedAt ? null : (lastReviewedAt ?? this.lastReviewedAt),
      nextReviewAt:
          clearNextReviewAt ? null : (nextReviewAt ?? this.nextReviewAt),
      masteryLevel: masteryLevel ?? this.masteryLevel,
      errorType: clearErrorType ? null : (errorType ?? this.errorType),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Mistake.fromMap(Map<String, dynamic> map) {
    return Mistake(
      id: map['id'] as int?,
      imagePath: map['image_path'] as String,
      title: map['title'] as String,
      tags: Mistake.normalizeTagsForStorage(
        List<String>.from(jsonDecode(map['tags'] as String)),
      ),
      solutions: List<String>.from(jsonDecode(map['solutions'] as String)),
      subject: map['subject'] as String? ?? '其他',
      category: map['category'] as String? ?? '一般',
      chapter: Mistake.normalizeChapterForStorage(map['chapter'] as String?),
      errorReason: map['error_reason'] as String?,
      reviewCount: map['review_count'] as int? ?? 0,
      lastReviewedAt: map['last_reviewed_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['last_reviewed_at'] as int),
      nextReviewAt: map['next_review_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['next_review_at'] as int),
      masteryLevel: map['mastery_level'] as int? ?? 0,
      errorType: map['error_type'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  /// AI 無法對應教科書章節時的占位字串；不應持久化，見 [normalizeChapterForStorage]、[normalizeTagsForStorage]。
  static const String pendingChapterPlaceholder = '待確認章節';

  /// 使用者透過「AI 做錯了」流程更正後寫入的標籤，供列表與詳解頁顯示標記。
  static const String aiCorrectionTag = 'AI 更正';

  /// 是否為「已含使用者更正／依答案推斷」的錯題（含舊資料：僅 solutions 字串符合時也視為已更正）。
  bool get hasAiCorrection {
    if (tags.contains(aiCorrectionTag)) return true;
    for (final s in solutions) {
      final t = s.trim();
      if (t.startsWith('正確答案：')) return true;
      if (t.contains('依答案推斷解法（請謹慎使用）')) return true;
    }
    return false;
  }

  /// 寫入／讀取資料時：占位章節不存 `chapter` 欄位。
  static String? normalizeChapterForStorage(String? chapter) {
    final t = chapter?.trim();
    if (t == null || t.isEmpty) return null;
    if (t == pendingChapterPlaceholder) return null;
    return t;
  }

  /// 寫入／讀取資料時：從 `tags` 移除占位章節字串。
  static List<String> normalizeTagsForStorage(List<String> tags) {
    return tags
        .where((t) => t.trim() != pendingChapterPlaceholder)
        .toList();
  }

  /// 列表／卡片／列印等 UI 顯示用（仍保留於資料庫，供內部邏輯使用）。
  List<String> get tagsForDisplay {
    return tags
        .where((t) => t != 'AI 解析' && t != pendingChapterPlaceholder)
        .toList();
  }

  String? get resolvedChapter {
    final stored = chapter?.trim();
    if (stored != null &&
        stored.isNotEmpty &&
        stored != pendingChapterPlaceholder) {
      return stored;
    }

    for (final tag in tags) {
      final normalized = tag.trim();
      if (normalized.isEmpty ||
          normalized == 'AI 解析' ||
          normalized == 'AI 練習題' ||
          normalized == pendingChapterPlaceholder) {
        continue;
      }
      return normalized;
    }
    return null;
  }

  List<String> get resolvedKeyConcepts {
    final chapterLabel = resolvedChapter;
    return tags
        .map((tag) => tag.trim())
        .where((tag) =>
            tag.isNotEmpty &&
            tag != 'AI 解析' &&
            tag != 'AI 練習題' &&
            tag != pendingChapterPlaceholder &&
            tag != chapterLabel)
        .toList();
  }
}
