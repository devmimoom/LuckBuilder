import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PremiumCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;

  const PremiumCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1), // 極細邊框
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
