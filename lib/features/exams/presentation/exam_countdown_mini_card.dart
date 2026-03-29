import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../providers/exam_countdown_provider.dart';

/// 首頁疊加用迷你倒數卡：便利貼風格（#FFD21F 深淺漸層、微傾斜、陰影），字級隨 [visualScale]／[FittedBox] 縮放。
class ExamCountdownMiniHeroCard extends StatelessWidget {
  const ExamCountdownMiniHeroCard({
    super.key,
    required this.exam,
    this.visualScale = 0.56,
  });

  final ExamCountdown exam;

  /// 整體縮放（預設略小於 2/3，讓首頁佔位更精緻）。
  final double visualScale;

  static const double _designW = 228;
  static const double _designH = 142;

  static const Color _stickyCore = Color(0xFFFFD21F);
  static const Color _stickyLight = Color(0xFFFFF0B8);
  static const Color _stickyDark = Color(0xFFE6B010);

  static const Color _countdownText = Color(0xFFFF2828);

  static const Color _stickyBorder = Color(0xFFD4A010);

  static const double _tiltRad = -0.052;

  @override
  Widget build(BuildContext context) {
    const titleColor = Color(0xFF6D6762);
    const nameColor = Color(0xFF625C57);
    const onSub = Color(0xFF8A8278);

    final card = Container(
      width: _designW,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _stickyLight,
            _stickyCore,
            _stickyDark,
          ],
          stops: [0.0, 0.48, 1.0],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _stickyBorder.withValues(alpha: 0.42),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            offset: const Offset(4, 6),
            blurRadius: 14,
            spreadRadius: -1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(1, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 7,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '考試倒數',
            style: TextStyle(
              color: titleColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              shadows: [
                Shadow(
                  color: Colors.white.withValues(alpha: 0.22),
                  offset: const Offset(0, 0.5),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      exam.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: nameColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('yyyy/MM/dd').format(exam.examDate),
                      style: TextStyle(
                        color: onSub,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                examCountdownLabel(exam),
                style: const TextStyle(
                  color: _countdownText,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // 微傾斜後外接矩形略大，預留空間避免裁切。
    const rotationSlack = 24.0;

    return SizedBox(
      width: (_designW + rotationSlack) * visualScale,
      height: (_designH + rotationSlack) * visualScale,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.topRight,
        child: Transform.rotate(
          angle: _tiltRad,
          alignment: Alignment.center,
          child: card,
        ),
      ),
    );
  }
}
