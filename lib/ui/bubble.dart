import 'package:flutter/material.dart';
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

  Widget _buildCircleContent(AppTokens tokens) {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) {
      return Center(
        child: Icon(
          Icons.auto_awesome,
          size: 22,
          color: tokens.primary,
        ),
      );
    }
    return ClipOval(
      child: Image.network(
        url,
        width: 82,
        height: 82,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: Icon(
              Icons.auto_awesome,
              size: 22,
              color: tokens.primary,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Icon(
              Icons.auto_awesome,
              size: 22,
              color: tokens.primary,
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
        child: SizedBox(
          width: 96,
          child: Column(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
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
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildCircleContent(tokens),
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
