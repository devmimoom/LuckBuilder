import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/home_background_preset.dart';
import '../../../../core/theme/home_mesh_reference_colors.dart';

/// 全螢幕彌散漸變底：多層柔邊色團 + 輕模糊，不參與互動。
class HomeMeshBackground extends StatelessWidget {
  const HomeMeshBackground({
    super.key,
    required this.preset,
  });

  final HomeBackgroundPreset preset;

  @override
  Widget build(BuildContext context) {
    final p = preset;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                p.gradientTop,
                p.gradientMid,
                p.gradientBottom,
              ],
            ),
          ),
        ),
        ClipRect(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: HomeMeshReferenceColors.blurSigmaMesh,
              sigmaY: HomeMeshReferenceColors.blurSigmaMesh,
            ),
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -90,
                  left: -70,
                  child: _blob(
                    diameter: 300,
                    colors: [
                      p.blobTeal.withValues(alpha: 0.46),
                      Colors.transparent,
                    ],
                  ),
                ),
                Positioned(
                  top: 120,
                  right: -80,
                  child: _blob(
                    diameter: 280,
                    colors: [
                      p.blobLavender.withValues(alpha: 0.40),
                      Colors.transparent,
                    ],
                  ),
                ),
                Positioned(
                  bottom: 80,
                  left: -60,
                  child: _blob(
                    diameter: 320,
                    colors: [
                      p.blobPeach.withValues(alpha: 0.42),
                      Colors.transparent,
                    ],
                  ),
                ),
                Positioned(
                  bottom: -40,
                  right: -20,
                  child: _blob(
                    diameter: 260,
                    colors: [
                      p.blobPinkMist.withValues(alpha: 0.36),
                      p.blobLavender.withValues(alpha: 0.26),
                      Colors.transparent,
                    ],
                  ),
                ),
                Positioned(
                  top: 200,
                  left: 80,
                  child: _blob(
                    diameter: 220,
                    colors: [
                      p.blobPinkMist.withValues(alpha: 0.34),
                      p.blobPeach.withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _blob({
    required double diameter,
    required List<Color> colors,
  }) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: colors,
          stops: colors.length == 3
              ? const [0.0, 0.55, 1.0]
              : const [0.0, 1.0],
        ),
      ),
    );
  }
}
