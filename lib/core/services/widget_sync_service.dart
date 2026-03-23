import 'package:flutter/material.dart';
import 'package:glance_widget/glance_widget.dart';

class WidgetSyncService {
  WidgetSyncService._();

  static const String reviewWidgetId = 'luckbuilder_review_widget';
  static const String reviewDeepLink = 'luckbuilder://review';

  static Future<void> syncExamCountdownWidget({
    required String title,
    required String value,
    required String subtitle,
  }) async {
    try {
      await GlanceWidget.simple(
        id: reviewWidgetId,
        title: title,
        value: value,
        subtitle: subtitle,
        subtitleColor: const Color(0xFF6366F1),
        deepLinkUri: reviewDeepLink,
      );
    } catch (_) {
      // Widget 在未支援的平台或尚未完成原生設定時，忽略即可。
    }
  }

  static Future<void> syncEmptyWidget() async {
    await syncExamCountdownWidget(
      title: 'LuckBuilder',
      value: '開始複習',
      subtitle: '點一下直接進入複習',
    );
  }
}
