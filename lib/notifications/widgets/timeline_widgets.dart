import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

class TLRow {
  final bool isHeader;
  final String? dayKey;
  final dynamic item;
  final int? seqInDayForProduct;

  TLRow._({
    required this.isHeader,
    this.dayKey,
    this.item,
    this.seqInDayForProduct,
  });

  factory TLRow.header(String dayKey) => TLRow._(isHeader: true, dayKey: dayKey);

  factory TLRow.item(dynamic item, {int? seqInDayForProduct}) =>
      TLRow._(isHeader: false, item: item, seqInDayForProduct: seqInDayForProduct);
}

String tlDayKey(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String tlTimeOnly(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

Widget tlTag(BuildContext context, String text, IconData icon) {
  final tokens = context.tokens;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: tokens.cardBorder.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: tokens.cardBorder),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: tokens.textPrimary),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

Widget tlTimelineRow({
  required BuildContext context,
  required DateTime when,
  required String title,
  required String preview,
  required String metaText,
  required dynamic saved, // SavedContent?
  required int? seqInDay,
  required bool isFirst,
  required bool isLast,
  required VoidCallback onTap,
  Widget? trailing,
  int? dayN, // Day N for "Day N · title" when > 0
  String? doneLabel,
  String? savedLabel,
}) {
  final tokens = context.tokens;
  const axisWidth = 76.0;
  const dotSize = 10.0;

  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左側時間線
        SizedBox(
          width: axisWidth,
          child: Column(
            children: [
              SizedBox(
                height: 10,
                child: Center(
                  child: Container(
                    width: 2,
                    color: isFirst
                        ? Colors.transparent
                        : tokens.cardBorder,
                  ),
                ),
              ),
              Row(
                children: [
                  const SizedBox(width: 10),
                  Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tokens.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${tlTimeOnly(when)}${seqInDay != null ? ' · #$seqInDay' : ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: tokens.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 28,
                child: Center(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : tokens.cardBorder,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // 右側卡片
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 右上 meta
                    Row(
                      children: [
                        const Spacer(),
                        if (metaText.isNotEmpty)
                          Text(
                            metaText,
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    // 狀態 chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if ((saved?.learned ?? false))
                          tlTag(context, doneLabel ?? 'Done', Icons.check_circle),
                        if ((saved?.favorite ?? false))
                          tlTag(context, savedLabel ?? 'Saved', Icons.star),
                      ],
                    ),
                    if ((saved?.learned ?? false) ||
                        (saved?.favorite ?? false))
                      const SizedBox(height: 8),
                    Text(
                      (dayN != null && dayN > 0) ? 'Day $dayN · $title' : title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(height: 10),
                      trailing,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
