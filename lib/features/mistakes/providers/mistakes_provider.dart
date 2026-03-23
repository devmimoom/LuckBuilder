import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/models/mistake.dart';
import '../../../core/utils/image_path_helper.dart';

part 'mistakes_provider.g.dart';

Future<List<Mistake>> _loadAllMistakesWithImageMigration(
  DatabaseHelper dbHelper,
) async {
  final allMistakes = await dbHelper.getAllMistakes();
  return _migrateLegacyImagePathsIfNeeded(dbHelper, allMistakes);
}

Future<List<Mistake>> _migrateLegacyImagePathsIfNeeded(
  DatabaseHelper dbHelper,
  List<Mistake> mistakes,
) async {
  if (mistakes.isEmpty) return mistakes;

  bool hasMigration = false;
  final migratedMistakes = <Mistake>[];

  for (final mistake in mistakes) {
    final resolvedPath =
        await ImagePathHelper.resolveStoredImagePath(mistake.imagePath);
    final persistentPath =
        await ImagePathHelper.ensurePersistentImagePath(resolvedPath);

    if (persistentPath != mistake.imagePath) {
      final updatedMistake = mistake.copyWith(imagePath: persistentPath);
      await dbHelper.updateMistake(updatedMistake);
      migratedMistakes.add(updatedMistake);
      hasMigration = true;
    } else {
      migratedMistakes.add(mistake);
    }
  }

  if (hasMigration) {
    debugPrint('✅ 已自動遷移舊版錯題圖片路徑到永久資料夾');
  }

  return migratedMistakes;
}

final allMistakesRawProvider = FutureProvider<List<Mistake>>((ref) async {
  ref.watch(mistakesProvider);
  return _loadAllMistakesWithImageMigration(DatabaseHelper());
});

@riverpod
class MistakeFilters extends _$MistakeFilters {
  @override
  Map<String, dynamic> build() {
    return {
      'subject': '全部',
      'searchQuery': '',
      'timeFilter': null, // 'first_exam', 'recent', 'old'
      'errorFilter': null, // 'frequent', null
      'tagFilter': null, // 標籤名稱，如 '一元二次方程式'
      'customTags': <String>[], // 自訂標籤列表（支持多個）
    };
  }

  void setSubject(String subject) {
    state = {...state, 'subject': subject};
  }

  void setSearchQuery(String query) {
    state = {...state, 'searchQuery': query};
  }

  void setTimeFilter(String? timeFilter) {
    state = {...state, 'timeFilter': timeFilter};
  }

  void setErrorFilter(String? errorFilter) {
    state = {...state, 'errorFilter': errorFilter};
  }

  void setTagFilter(String? tagFilter) {
    state = {...state, 'tagFilter': tagFilter};
  }

  void addCustomTag(String tag) {
    final currentTags = List<String>.from(state['customTags'] ?? []);
    if (!currentTags.contains(tag)) {
      currentTags.add(tag);
      state = {...state, 'customTags': currentTags};
    }
  }

  void removeCustomTag(String tag) {
    final currentTags = List<String>.from(state['customTags'] ?? []);
    currentTags.remove(tag);
    state = {...state, 'customTags': currentTags};
  }

  void clearFilters() {
    state = {
      'subject': '全部',
      'searchQuery': '',
      'timeFilter': null,
      'errorFilter': null,
      'tagFilter': null,
      'customTags': <String>[],
    };
  }
}

@riverpod
class Mistakes extends _$Mistakes {
  final _dbHelper = DatabaseHelper();

  @override
  FutureOr<List<Mistake>> build() async {
    final filters = ref.watch(mistakeFiltersProvider);
    final allMistakes = await _loadAllMistakesWithImageMigration(_dbHelper);

    return allMistakes.where((m) {
      // 科目篩選
      final matchesSubject =
          filters['subject'] == '全部' || m.subject == filters['subject'];

      // 搜尋篩選（同時搜尋標題、標籤、科目、分類）
      final searchQuery = filters['searchQuery'].toString();
      final matchesSearch = searchQuery.isEmpty ||
          m.title.contains(searchQuery) ||
          m.subject.contains(searchQuery) ||
          m.category.contains(searchQuery) ||
          (m.resolvedChapter?.contains(searchQuery) ?? false) ||
          m.tags.any((t) => t.contains(searchQuery));

      // 時間篩選（第一次段考：假設是最近一個月的題目）
      bool matchesTime = true;
      if (filters['timeFilter'] == 'first_exam') {
        final now = DateTime.now();
        final oneMonthAgo = now.subtract(const Duration(days: 30));
        matchesTime = m.createdAt.isAfter(oneMonthAgo);
      }

      // 常錯篩選（基於 subject + category 統計近 30 天內錯誤次數）
      bool matchesError = true;
      if (filters['errorFilter'] == 'frequent') {
        // 統計同一 subject + category 在近 30 天內的錯題數量
        final now = DateTime.now();
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));

        // 計算相同分類的錯題數量（近 30 天內）
        final sameCategoryCount = allMistakes.where((otherMistake) {
          return otherMistake.subject == m.subject &&
              otherMistake.category == m.category &&
              otherMistake.createdAt.isAfter(thirtyDaysAgo);
        }).length;

        // 如果同一分類的錯題達到 2 次以上，視為「常錯」
        matchesError = sameCategoryCount >= 2;
      }

      // 標籤篩選（固定標籤）
      bool matchesTag = true;
      if (filters['tagFilter'] != null) {
        matchesTag = m.tags.contains(filters['tagFilter'].toString());
      }

      // 自訂標籤篩選（支持多個，AND 邏輯）
      bool matchesCustomTags = true;
      final customTags = filters['customTags'] as List<dynamic>? ?? [];
      if (customTags.isNotEmpty) {
        // 所有自訂標籤都必須在題目的標籤中（AND 邏輯）
        matchesCustomTags = customTags.every((customTag) {
          final tagStr = customTag.toString();
          // 支持精確匹配和模糊匹配（包含）
          return m.tags.any((tag) => tag == tagStr || tag.contains(tagStr));
        });
      }

      return matchesSubject &&
          matchesSearch &&
          matchesTime &&
          matchesError &&
          matchesTag &&
          matchesCustomTags;
    }).toList();
  }

  Future<void> addMistake({
    required String imagePath,
    required String title,
    required List<String> tags,
    required List<String> solutions,
    required String subject,
    required String category,
    String? chapter,
    String? errorReason,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // 保險機制：任何入口新增錯題都統一確保圖片為永久路徑，
      // 避免臨時目錄被系統清除後出現「圖片消失」。
      final persistentImagePath =
          await ImagePathHelper.ensurePersistentImagePath(imagePath);

      final mistake = Mistake(
        imagePath: persistentImagePath,
        title: title,
        tags: tags,
        solutions: solutions,
        subject: subject,
        category: category,
        chapter: chapter,
        errorReason: errorReason,
        errorType: errorReason,
        nextReviewAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await _dbHelper.insertMistake(mistake);
      return await _fetchFilteredMistakes();
    });
  }

  Future<List<Mistake>> _fetchFilteredMistakes() async {
    final filters = ref.read(mistakeFiltersProvider);
    final allMistakes = await _loadAllMistakesWithImageMigration(_dbHelper);
    return allMistakes.where((m) {
      final matchesSubject =
          filters['subject'] == '全部' || m.subject == filters['subject'];

      final searchQuery = filters['searchQuery'].toString();
      final matchesSearch = searchQuery.isEmpty ||
          m.title.contains(searchQuery) ||
          m.subject.contains(searchQuery) ||
          m.category.contains(searchQuery) ||
          (m.resolvedChapter?.contains(searchQuery) ?? false) ||
          m.tags.any((t) => t.contains(searchQuery));

      // 時間篩選
      bool matchesTime = true;
      if (filters['timeFilter'] == 'first_exam') {
        final now = DateTime.now();
        final oneMonthAgo = now.subtract(const Duration(days: 30));
        matchesTime = m.createdAt.isAfter(oneMonthAgo);
      }

      // 常錯篩選（基於 subject + category 統計近 30 天內錯誤次數）
      bool matchesError = true;
      if (filters['errorFilter'] == 'frequent') {
        // 統計同一 subject + category 在近 30 天內的錯題數量
        final now = DateTime.now();
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));

        // 計算相同分類的錯題數量（近 30 天內）
        final sameCategoryCount = allMistakes.where((otherMistake) {
          return otherMistake.subject == m.subject &&
              otherMistake.category == m.category &&
              otherMistake.createdAt.isAfter(thirtyDaysAgo);
        }).length;

        // 如果同一分類的錯題達到 2 次以上，視為「常錯」
        matchesError = sameCategoryCount >= 2;
      }

      // 標籤篩選（固定標籤）
      bool matchesTag = true;
      if (filters['tagFilter'] != null) {
        matchesTag = m.tags.contains(filters['tagFilter'].toString());
      }

      // 自訂標籤篩選
      bool matchesCustomTags = true;
      final customTags = filters['customTags'] as List<dynamic>? ?? [];
      if (customTags.isNotEmpty) {
        matchesCustomTags = customTags.every((customTag) {
          final tagStr = customTag.toString();
          return m.tags.any((tag) => tag == tagStr || tag.contains(tagStr));
        });
      }

      return matchesSubject &&
          matchesSearch &&
          matchesTime &&
          matchesError &&
          matchesTag &&
          matchesCustomTags;
    }).toList();
  }

  Future<void> deleteMistake(int id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final targetMistake = await _dbHelper.getMistakeById(id);
      await _dbHelper.deleteMistake(id);
      if (targetMistake != null) {
        await ImagePathHelper.deleteImage(targetMistake.imagePath);
      }
      return await _fetchFilteredMistakes();
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return await _fetchFilteredMistakes();
    });
  }

  Future<void> updateMistakeSubjectAndCategory({
    required int id,
    required String subject,
    required String category,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // 先獲取原始錯題
      final originalMistake = await _dbHelper.getMistakeById(id);
      if (originalMistake != null) {
        final updatedMistake = originalMistake.copyWith(
          subject: subject,
          category: category,
        );
        await _dbHelper.updateMistake(updatedMistake);
      }
      return await _fetchFilteredMistakes();
    });
  }

  Future<void> updateMistakeTags({
    required int id,
    required String subject,
    required String category,
    required List<String> tags,
    String? chapter,
  }) async {
    debugPrint("💾 updateMistakeTags 被調用");
    debugPrint("   id: $id");
    debugPrint("   subject: $subject");
    debugPrint("   category: $category");
    debugPrint("   tags: $tags");

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // 先獲取原始錯題
      final originalMistake = await _dbHelper.getMistakeById(id);
      if (originalMistake == null) {
        debugPrint("   ❌ 找不到錯題，id: $id");
        throw Exception("找不到錯題，id: $id");
      }

      debugPrint("   ✅ 找到錯題，開始更新");

      final updatedMistake = originalMistake.copyWith(
        tags: tags,
        subject: subject,
        category: category,
        chapter: chapter,
      );

      final result = await _dbHelper.updateMistake(updatedMistake);
      debugPrint("   ✅ 資料庫更新完成，影響行數: $result");

      return await _fetchFilteredMistakes();
    });
  }

  Future<void> updateMistakeTitle({
    required int id,
    required String title,
  }) async {
    state = await AsyncValue.guard(() async {
      final originalMistake = await _dbHelper.getMistakeById(id);
      if (originalMistake == null) {
        throw Exception("找不到錯題，id: $id");
      }

      final updatedMistake = originalMistake.copyWith(title: title);

      await _dbHelper.updateMistake(updatedMistake);
      return await _fetchFilteredMistakes();
    });
  }

  Future<void> updateMistakeReviewData({
    required int id,
    required int reviewCount,
    required int masteryLevel,
    required DateTime lastReviewedAt,
    required DateTime nextReviewAt,
    String? errorType,
  }) async {
    state = await AsyncValue.guard(() async {
      final originalMistake = await _dbHelper.getMistakeById(id);
      if (originalMistake == null) {
        throw Exception("找不到錯題，id: $id");
      }

      final updatedMistake = originalMistake.copyWith(
        reviewCount: reviewCount,
        masteryLevel: masteryLevel,
        lastReviewedAt: lastReviewedAt,
        nextReviewAt: nextReviewAt,
        errorType: errorType,
      );

      await _dbHelper.updateMistake(updatedMistake);
      return await _fetchFilteredMistakes();
    });
  }
}

@riverpod
Future<Mistake?> mistakeById(Ref ref, int id) async {
  final dbHelper = DatabaseHelper();
  final mistake = await dbHelper.getMistakeById(id);
  if (mistake == null) return null;

  final migratedMistakes = await _migrateLegacyImagePathsIfNeeded(
    dbHelper,
    [mistake],
  );
  return migratedMistakes.first;
}
