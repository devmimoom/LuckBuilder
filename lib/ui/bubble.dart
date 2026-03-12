import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';

class BubbleCircle extends StatefulWidget {
  final String title;
  final VoidCallback onTap;
  /// Topic 泡泡圖片 URL；為 null 或空時顯示預設漸層與圖示
  final String? imageUrl;

  const BubbleCircle({
    super.key,
    required this.title,
    required this.onTap,
    this.imageUrl,
  });

  @override
  State<BubbleCircle> createState() => _BubbleCircleState();
}

class _BubbleCircleState extends State<BubbleCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const double _cardWidth = 90;
  static const double _cardHeight = 90;
  static const double _imageHeight = 90;
  static const double _cornerRadius = 16;

  Widget _buildCardContent(AppTokens tokens) {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        height: _imageHeight,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(_cornerRadius)),
          gradient: tokens.chipGradient ??
              LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tokens.chipBg,
                  tokens.chipBg.withValues(alpha: 0.7),
                ],
              ),
        ),
        child: Center(
          child: Icon(
            Icons.auto_awesome,
            size: 28,
            color: tokens.primary,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(_cornerRadius)),
      child: CachedNetworkImage(
        imageUrl: url,
        width: double.infinity,
        height: _imageHeight,
        fit: BoxFit.cover,
        placeholder: (context, url) => SizedBox(
          height: _imageHeight,
          child: Center(
            child: Icon(
              Icons.auto_awesome,
              size: 28,
              color: tokens.primary,
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          return SizedBox(
            height: _imageHeight,
            child: Center(
              child: Icon(
                Icons.auto_awesome,
                size: 28,
                color: tokens.primary,
              ),
            ),
          );
        },
      ),
    );
  }

  bool get _hasImageUrl =>
      widget.imageUrl != null && widget.imageUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _cardWidth,
              height: _cardHeight,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_cornerRadius),
                  color: _hasImageUrl ? tokens.chipBg : null,
                  gradient: _hasImageUrl
                      ? null
                      : (tokens.chipGradient ??
                          LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              tokens.chipBg,
                              tokens.chipBg.withValues(alpha: 0.7),
                            ],
                          )),
                  border: Border.all(
                    color: tokens.cardBorder,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.primary.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildCardContent(tokens),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: _cardWidth,
              child: Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
