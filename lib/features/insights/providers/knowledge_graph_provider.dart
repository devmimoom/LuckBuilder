import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/models/mistake.dart';
import '../../mistakes/providers/mistakes_provider.dart';

// ---------------------------------------------------------------------------
// Data models – hierarchical: Subject → Category → Chapter / Concept
// ---------------------------------------------------------------------------

class ConceptNode {
  const ConceptNode({
    required this.label,
    required this.mistakes,
    required this.averageMastery,
  });

  final String label;
  final List<Mistake> mistakes;
  final double averageMastery;

  int get count => mistakes.length;

  int get dueCount => mistakes
      .where((m) =>
          m.nextReviewAt == null || !m.nextReviewAt!.isAfter(DateTime.now()))
      .length;
}

class ChapterInfo {
  const ChapterInfo({
    required this.name,
    required this.mistakes,
    required this.averageMastery,
  });

  final String name;
  final List<Mistake> mistakes;
  final double averageMastery;

  int get count => mistakes.length;
}

class CategoryCluster {
  const CategoryCluster({
    required this.category,
    required this.mistakes,
    required this.chapters,
    required this.concepts,
    required this.averageMastery,
  });

  final String category;
  final List<Mistake> mistakes;
  final List<ChapterInfo> chapters;
  final List<ConceptNode> concepts;
  final double averageMastery;

  int get count => mistakes.length;

  int get dueCount => mistakes
      .where((m) =>
          m.nextReviewAt == null || !m.nextReviewAt!.isAfter(DateTime.now()))
      .length;
}

class SubjectGroup {
  const SubjectGroup({
    required this.subject,
    required this.categories,
    required this.totalMistakes,
    required this.averageMastery,
  });

  final String subject;
  final List<CategoryCluster> categories;
  final int totalMistakes;
  final double averageMastery;
}

class KnowledgeMapData {
  const KnowledgeMapData({
    required this.subjects,
    required this.weakestConcepts,
    required this.totalConcepts,
    required this.totalMistakes,
  });

  final List<SubjectGroup> subjects;
  final List<ConceptNode> weakestConcepts;
  final int totalConcepts;
  final int totalMistakes;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final knowledgeGraphProvider = FutureProvider<KnowledgeMapData>((ref) async {
  final mistakes = await ref.watch(allMistakesRawProvider.future);

  final subjectCategoryMap = <String, Map<String, List<Mistake>>>{};
  for (final m in mistakes) {
    final subject = m.subject.trim().isEmpty ? '其他' : m.subject.trim();
    final category = m.category.trim().isEmpty ? '一般' : m.category.trim();
    subjectCategoryMap.putIfAbsent(subject, () => {});
    subjectCategoryMap[subject]!.putIfAbsent(category, () => []);
    subjectCategoryMap[subject]![category]!.add(m);
  }

  final globalConceptMap = <String, List<Mistake>>{};

  final subjects = <SubjectGroup>[];
  for (final subjectEntry in subjectCategoryMap.entries) {
    final categories = <CategoryCluster>[];

    for (final catEntry in subjectEntry.value.entries) {
      final catMistakes = catEntry.value;

      // Chapters
      final chapterMap = <String, List<Mistake>>{};
      for (final m in catMistakes) {
        final ch = m.resolvedChapter?.trim();
        if (ch != null && ch.isNotEmpty) {
          chapterMap.putIfAbsent(ch, () => []);
          chapterMap[ch]!.add(m);
        }
      }
      final chapters = chapterMap.entries.map((e) {
        final avg = e.value.isEmpty
            ? 0.0
            : e.value.fold<int>(0, (s, m) => s + m.masteryLevel) /
                e.value.length;
        return ChapterInfo(name: e.key, mistakes: e.value, averageMastery: avg);
      }).toList()
        ..sort((a, b) => b.count.compareTo(a.count));

      // Concepts
      final conceptMap = <String, List<Mistake>>{};
      for (final m in catMistakes) {
        for (final concept in m.resolvedKeyConcepts.take(5)) {
          final n = concept.trim();
          if (n.isEmpty) continue;
          conceptMap.putIfAbsent(n, () => []);
          conceptMap[n]!.add(m);
          globalConceptMap.putIfAbsent(n, () => []);
          if (!globalConceptMap[n]!.any((x) => x.id == m.id)) {
            globalConceptMap[n]!.add(m);
          }
        }
      }
      final concepts = conceptMap.entries.map((e) {
        final avg = e.value.isEmpty
            ? 0.0
            : e.value.fold<int>(0, (s, m) => s + m.masteryLevel) /
                e.value.length;
        return ConceptNode(
            label: e.key, mistakes: e.value, averageMastery: avg);
      }).toList()
        ..sort((a, b) => b.count.compareTo(a.count));

      final catAvg = catMistakes.isEmpty
          ? 0.0
          : catMistakes.fold<int>(0, (s, m) => s + m.masteryLevel) /
              catMistakes.length;

      categories.add(CategoryCluster(
        category: catEntry.key,
        mistakes: catMistakes,
        chapters: chapters,
        concepts: concepts,
        averageMastery: catAvg,
      ));
    }

    categories.sort((a, b) => b.count.compareTo(a.count));

    final allSubjectMistakes =
        subjectEntry.value.values.expand((l) => l).toList();
    final subjectAvg = allSubjectMistakes.isEmpty
        ? 0.0
        : allSubjectMistakes.fold<int>(0, (s, m) => s + m.masteryLevel) /
            allSubjectMistakes.length;

    subjects.add(SubjectGroup(
      subject: subjectEntry.key,
      categories: categories,
      totalMistakes: allSubjectMistakes.length,
      averageMastery: subjectAvg,
    ));
  }

  subjects.sort((a, b) => b.totalMistakes.compareTo(a.totalMistakes));

  final weakest = globalConceptMap.entries.map((e) {
    final avg = e.value.isEmpty
        ? 0.0
        : e.value.fold<int>(0, (s, m) => s + m.masteryLevel) / e.value.length;
    return ConceptNode(label: e.key, mistakes: e.value, averageMastery: avg);
  }).toList()
    ..sort((a, b) => a.averageMastery.compareTo(b.averageMastery));

  return KnowledgeMapData(
    subjects: subjects,
    weakestConcepts: weakest.take(8).toList(),
    totalConcepts: globalConceptMap.length,
    totalMistakes: mistakes.length,
  );
});
