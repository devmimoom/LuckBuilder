import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class PremiumCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;

  /// 白底不透明度（預設略透以配合彌散底；設定頁可再調低）。
  final double backgroundOpacity;

  /// 與白底疊加淡色（例如首頁六色票指標卡）。
  final Color? surfaceTint;

  const PremiumCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(16),
    this.backgroundOpacity = 0.88,
    this.surfaceTint,
  });

  @override
  Widget build(BuildContext context) {
    final base = Colors.white.withValues(alpha: backgroundOpacity);
    final fill = surfaceTint == null
        ? base
        : Color.alphaBlend(surfaceTint!.withValues(alpha: 0.42), base);
    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.65),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03), // 3% 透明度的陰影
            offset: const Offset(0, 4),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          splashColor: Colors.black.withValues(alpha: 0.05), // 墨水漣漪
          highlightColor: Colors.black.withValues(alpha: 0.02),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
