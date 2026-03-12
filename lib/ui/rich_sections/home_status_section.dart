import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/rich_sections/learning_metrics_providers.dart';

class HomeStatusSection extends ConsumerWidget {
  const HomeStatusSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(globalStreakProvider);
    final weeklyAsync = ref.watch(globalWeeklyCountProvider);

    Widget pill(String title, String value, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.35),
          ),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall),
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ]),
            ],
          ),
        ),
      );
    }

    final streakText = streakAsync.when(
      data: (s) => '$s days',
      loading: () => '…',
      error: (_, __) => '—',
    );

    final weeklyText = weeklyAsync.when(
      data: (w) => '$w/7 days',
      loading: () => '…',
      error: (_, __) => '—',
    );

    return Row(
      children: [
        pill('Streak', streakText, Icons.local_fire_department),
        const SizedBox(width: AppSpacing.xs),
        pill('This week', weeklyText, Icons.insights),
        const SizedBox(width: AppSpacing.xs),
        pill('Top category', 'AI', Icons.auto_awesome),
      ],
    );
  }
}
