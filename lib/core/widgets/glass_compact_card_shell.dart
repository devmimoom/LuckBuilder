import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/home_mesh_reference_colors.dart';

/// 與首頁「最近錯題」小卡相同的玻璃殼（彌散底上可讀）。
class GlassCompactCardShell extends StatelessWidget {
  const GlassCompactCardShell({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  static const double _r = HomeMeshReferenceColors.radiusGlassCompact;

  @override
  Widget build(BuildContext context) {
    Widget inner = Padding(
      padding: padding,
      child: child,
    );
    if (onTap != null || onLongPress != null) {
      inner = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(_r),
          splashColor: Colors.white.withValues(alpha: 0.14),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: inner,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(_r),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: HomeMeshReferenceColors.blurSigmaCard,
          sigmaY: HomeMeshReferenceColors.blurSigmaCard,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: HomeMeshReferenceColors.glassFillLight,
            borderRadius: BorderRadius.circular(_r),
            border: Border.all(color: HomeMeshReferenceColors.glassBorderWhite),
          ),
          child: inner,
        ),
      ),
    );
  }
}
