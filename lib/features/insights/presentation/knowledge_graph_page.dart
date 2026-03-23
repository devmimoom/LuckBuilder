import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/models/mistake.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_ux.dart';
import '../../../core/utils/latex_helper.dart';
import '../../../core/widgets/premium_card.dart';
import '../../solver/presentation/solver_page.dart';
import '../providers/knowledge_graph_provider.dart';

// ---------------------------------------------------------------------------
// Palette helpers
// ---------------------------------------------------------------------------

const _subjectPalette = <String, Color>{
  '數學': Color(0xFF2563EB),
  '英文': Color(0xFF059669),
  '物理': Color(0xFFEA580C),
  '化學': Color(0xFF8B5CF6),
  '生物': Color(0xFF0891B2),
  '國文': Color(0xFFBE185D),
  '社會': Color(0xFF4338CA),
  '地理': Color(0xFF16A34A),
  '歷史': Color(0xFFB45309),
};

Color _subjectColor(String subject) {
  if (_subjectPalette.containsKey(subject)) return _subjectPalette[subject]!;
  final hash = subject.hashCode.abs();
  return HSLColor.fromAHSL(1, (hash % 360).toDouble(), 0.55, 0.45).toColor();
}

Color _masteryColor(double mastery) {
  if (mastery >= 1.6) return const Color(0xFF16A34A);
  if (mastery >= 0.8) return const Color(0xFFF59E0B);
  return const Color(0xFFDC2626);
}

double _masteryRatio(double mastery) => (mastery / 2.0).clamp(0.0, 1.0);

String _masteryLabel(double mastery) =>
    '${(_masteryRatio(mastery) * 100).round()}%';

// ===========================================================================
// Page
// ===========================================================================

class KnowledgeGraphPage extends ConsumerStatefulWidget {
  const KnowledgeGraphPage({super.key});

  @override
  ConsumerState<KnowledgeGraphPage> createState() => _KnowledgeGraphPageState();
}

class _KnowledgeGraphPageState extends ConsumerState<KnowledgeGraphPage> {
  String? _selectedSubject;

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(knowledgeGraphProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: dataAsync.when(
        data: (data) =>
            data.totalMistakes == 0 ? const _EmptyState() : _buildBody(data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('載入失敗：$e')),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Body
  // -------------------------------------------------------------------------

  Widget _buildBody(KnowledgeMapData data) {
    final visible = _selectedSubject == null
        ? data.subjects
        : data.subjects.where((s) => s.subject == _selectedSubject).toList();
    final allCategories =
        visible.expand((s) => s.categories.map((c) => (s.subject, c))).toList();

    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          floating: true,
          backgroundColor: Color(0xFFFAFAFA),
          title: Text('知識地圖'),
          elevation: 0,
        ),
        SliverToBoxAdapter(child: _Header(data: data)),
        SliverToBoxAdapter(child: _StatsRow(data: data)),
        if (data.subjects.length > 1)
          SliverToBoxAdapter(
            child: _SubjectFilter(
              subjects: data.subjects,
              selected: _selectedSubject,
              onSelect: (s) => setState(() => _selectedSubject = s),
            ),
          ),
        if (data.weakestConcepts.isNotEmpty && _selectedSubject == null)
          SliverToBoxAdapter(
            child: _WeakSpots(
              concepts: data.weakestConcepts,
              onTap: _showConceptSheet,
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          sliver: SliverList.builder(
            itemCount: allCategories.length,
            itemBuilder: (context, index) {
              final (subject, cluster) = allCategories[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CategoryCard(
                  subject: subject,
                  cluster: cluster,
                  onTapConcept: _showConceptSheet,
                  onTapChapter: _showChapterSheet,
                  onTapMistake: _openSolver,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Bottom sheets
  // -------------------------------------------------------------------------

  void _showConceptSheet(ConceptNode c) => _showMistakesSheet(
        title: c.label,
        subtitle: '${c.count} 題 · 掌握 ${_masteryLabel(c.averageMastery)}',
        mistakes: c.mistakes,
        accent: _masteryColor(c.averageMastery),
      );

  void _showChapterSheet(ChapterInfo ch) => _showMistakesSheet(
        title: ch.name,
        subtitle: '${ch.count} 題 · 掌握 ${_masteryLabel(ch.averageMastery)}',
        mistakes: ch.mistakes,
        accent: const Color(0xFF8B5CF6),
      );

  void _showMistakesSheet({
    required String title,
    required String subtitle,
    required List<Mistake> mistakes,
    required Color accent,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.72),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text(subtitle,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                shrinkWrap: true,
                itemCount: mistakes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _MistakeTile(
                  mistake: mistakes[i],
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openSolver(mistakes[i]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSolver(Mistake m) async {
    final image = m.imagePath.isNotEmpty ? File(m.imagePath) : null;
    await Navigator.of(context).push(
      AppUX.fadeRoute(
        SolverPage(
          originalImage: image,
          initialLatex: m.title,
          isFromMistakes: true,
          savedSolutions: m.solutions,
          subject: m.subject,
          category: m.category,
          chapter: m.resolvedChapter,
          keyConcepts: m.resolvedKeyConcepts,
          mistakeId: m.id,
        ),
      ),
    );
  }
}

// ===========================================================================
// Header banner
// ===========================================================================

class _Header extends StatelessWidget {
  const _Header({required this.data});
  final KnowledgeMapData data;

  @override
  Widget build(BuildContext context) {
    final weakCount =
        data.weakestConcepts.where((c) => c.averageMastery < 0.8).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  const Icon(Icons.hub_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('知識地圖',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '${data.totalConcepts} 個觀念'
                    '${weakCount > 0 ? ' · $weakCount 個待加強' : ''}',
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Stats row
// ===========================================================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.data});
  final KnowledgeMapData data;

  @override
  Widget build(BuildContext context) {
    final totalDue = data.subjects
        .expand((s) => s.categories)
        .fold<int>(0, (sum, c) => sum + c.dueCount);
    final avgMastery = data.totalMistakes == 0
        ? 0.0
        : data.subjects.fold<double>(
                0, (s, g) => s + g.averageMastery * g.totalMistakes) /
            data.totalMistakes;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          Expanded(
              child: _StatPill(
                  icon: Icons.bubble_chart_rounded,
                  label: '觀念',
                  value: '${data.totalConcepts}',
                  color: const Color(0xFF2563EB))),
          const SizedBox(width: 10),
          Expanded(
              child: _StatPill(
                  icon: Icons.speed_rounded,
                  label: '掌握度',
                  value: _masteryLabel(avgMastery),
                  color: _masteryColor(avgMastery))),
          const SizedBox(width: 10),
          Expanded(
              child: _StatPill(
                  icon: Icons.schedule_rounded,
                  label: '待複習',
                  value: '$totalDue',
                  color: totalDue > 0
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF16A34A))),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

// ===========================================================================
// Subject filter
// ===========================================================================

class _SubjectFilter extends StatelessWidget {
  const _SubjectFilter({
    required this.subjects,
    required this.selected,
    required this.onSelect,
  });
  final List<SubjectGroup> subjects;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        children: [
          _FilterChip(
            label: '全部',
            trailing: null,
            color: AppColors.textPrimary,
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          ...subjects.map((s) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _FilterChip(
                  label: s.subject,
                  trailing: '${s.totalMistakes}',
                  color: _subjectColor(s.subject),
                  selected: selected == s.subject,
                  onTap: () => onSelect(s.subject),
                ),
              )),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.trailing,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String? trailing;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13)),
            if (trailing != null) ...[
              const SizedBox(width: 5),
              Text(trailing!,
                  style: TextStyle(
                      color: selected ? Colors.white70 : AppColors.textTertiary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Weak spots horizontal list
// ===========================================================================

class _WeakSpots extends StatelessWidget {
  const _WeakSpots({required this.concepts, required this.onTap});
  final List<ConceptNode> concepts;
  final ValueChanged<ConceptNode> onTap;

  @override
  Widget build(BuildContext context) {
    final weak = concepts.where((c) => c.averageMastery < 1.2).toList();
    if (weak.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 18, color: Color(0xFFDC2626)),
              SizedBox(width: 6),
              Text('需要加強',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary)),
            ],
          ),
        ),
        SizedBox(
          height: 94,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            itemCount: weak.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) =>
                _WeakCard(concept: weak[i], onTap: () => onTap(weak[i])),
          ),
        ),
      ],
    );
  }
}

class _WeakCard extends StatelessWidget {
  const _WeakCard({required this.concept, required this.onTap});
  final ConceptNode concept;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _masteryColor(concept.averageMastery);
    final ratio = _masteryRatio(concept.averageMastery);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 152,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(concept.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                        value: ratio,
                        backgroundColor: const Color(0xFFEEEEEE),
                        color: color,
                        minHeight: 3),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${concept.count} 題',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Category card (expandable)
// ===========================================================================

class _CategoryCard extends StatefulWidget {
  const _CategoryCard({
    required this.subject,
    required this.cluster,
    required this.onTapConcept,
    required this.onTapChapter,
    required this.onTapMistake,
  });
  final String subject;
  final CategoryCluster cluster;
  final ValueChanged<ConceptNode> onTapConcept;
  final ValueChanged<ChapterInfo> onTapChapter;
  final ValueChanged<Mistake> onTapMistake;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.cluster;
    final ratio = _masteryRatio(c.averageMastery);
    final color = _masteryColor(c.averageMastery);
    final subjectC = _subjectColor(widget.subject);

    return PremiumCard(
      padding: EdgeInsets.zero,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        children: [
          // -- header --
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: subjectC.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child:
                        Icon(Icons.category_rounded, color: subjectC, size: 19),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(c.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppColors.textPrimary)),
                          ),
                          const SizedBox(width: 8),
                          _MiniTag(text: widget.subject, color: subjectC),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                  value: ratio,
                                  backgroundColor: const Color(0xFFEEEEEE),
                                  color: color,
                                  minHeight: 5),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('${(ratio * 100).round()}%',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: color)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('${c.count} 題',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more_rounded,
                      color: AppColors.textTertiary),
                ),
              ],
            ),
          ),

          // -- expanded body --
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? _ExpandedBody(
                      cluster: c,
                      onTapConcept: widget.onTapConcept,
                      onTapChapter: widget.onTapChapter,
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandedBody extends StatelessWidget {
  const _ExpandedBody({
    required this.cluster,
    required this.onTapConcept,
    required this.onTapChapter,
  });
  final CategoryCluster cluster;
  final ValueChanged<ConceptNode> onTapConcept;
  final ValueChanged<ChapterInfo> onTapChapter;

  @override
  Widget build(BuildContext context) {
    final c = cluster;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 14),
          if (c.chapters.isNotEmpty) ...[
            const _SectionLabel(
                icon: Icons.menu_book_rounded,
                label: '章節',
                color: Color(0xFF8B5CF6)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: c.chapters
                  .map((ch) =>
                      _ChapterChip(ch: ch, onTap: () => onTapChapter(ch)))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
          if (c.concepts.isNotEmpty) ...[
            const _SectionLabel(
                icon: Icons.lightbulb_outline_rounded,
                label: '核心觀念',
                color: Color(0xFFEA580C)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: c.concepts
                  .map((n) =>
                      _ConceptChip(node: n, onTap: () => onTapConcept(n)))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
          if (c.dueCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 14, color: Color(0xFFDC2626)),
                  const SizedBox(width: 6),
                  Text('${c.dueCount} 題待複習',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDC2626))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Small reusable widgets
// ===========================================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _ChapterChip extends StatelessWidget {
  const _ChapterChip({required this.ch, required this.onTap});
  final ChapterInfo ch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mColor = _masteryColor(ch.averageMastery);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 7,
                height: 7,
                decoration:
                    BoxDecoration(color: mColor, shape: BoxShape.circle)),
            const SizedBox(width: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(ch.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6D28D9))),
            ),
            const SizedBox(width: 6),
            Text('${ch.count}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6D28D9).withValues(alpha: 0.55))),
          ],
        ),
      ),
    );
  }
}

class _ConceptChip extends StatelessWidget {
  const _ConceptChip({required this.node, required this.onTap});
  final ConceptNode node;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _masteryColor(node.averageMastery);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(node.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

// ===========================================================================
// Mistake tile (used in bottom sheet)
// ===========================================================================

class _MistakeTile extends StatelessWidget {
  const _MistakeTile({required this.mistake, required this.onTap});
  final Mistake mistake;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mColor = _masteryColor(mistake.masteryLevel.toDouble());
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                  color: mColor, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LatexHelper.toReadableText(mistake.title,
                        fallback: '未命名題目'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.45),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _MiniTag(
                          text: mistake.subject,
                          color: _subjectColor(mistake.subject)),
                      if (mistake.resolvedChapter != null)
                        _MiniTag(
                            text: mistake.resolvedChapter!,
                            color: const Color(0xFF8B5CF6)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Empty state
// ===========================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('知識地圖'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hub_outlined, size: 64, color: AppColors.textTertiary),
              SizedBox(height: 16),
              Text('還沒有足夠資料',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              SizedBox(height: 10),
              Text(
                '先多累積幾題 AI 解析過的錯題，\n系統就能把分類、章節和核心觀念串成知識地圖。',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
