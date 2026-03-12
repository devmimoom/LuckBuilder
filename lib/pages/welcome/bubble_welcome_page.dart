import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_spacing.dart';
import '../../localization/app_language.dart';
import '../../localization/app_language_provider.dart';
import '../../localization/app_strings.dart';

class BubbleWelcomePage extends StatefulWidget {
  const BubbleWelcomePage({super.key, required this.onFinished});
  final VoidCallback onFinished;

  @override
  State<BubbleWelcomePage> createState() => _BubbleWelcomePageState();
}

class _BubbleWelcomePageState extends State<BubbleWelcomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final lang = ref.watch(appLanguageProvider);
        debugPrint(
          'BubbleWelcomePage build — lang=$lang, fadeValue=${_fadeController.value}',
        );
        return Scaffold(
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onFinished,
            child: FadeTransition(
              opacity: _fadeController,
              child: Stack(
                children: [
                  const Positioned.fill(child: _PremiumBackground()),
                  _CenterContent(lang: lang),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Premium gradient background
class _PremiumBackground extends StatelessWidget {
  const _PremiumBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A0E27),
            Color(0xFF1A1A3A),
            Color(0xFF0F1629),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

// Center content
class _CenterContent extends StatelessWidget {
  const _CenterContent({required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final isZh = lang == AppLanguage.zhTw;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'OnePop',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                  letterSpacing: 6,
                  height: 1.1,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              Text(
                uiString(lang, 'your_mental_snack'),
                style: TextStyle(
                  fontSize: isZh ? 16 : 17,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.65),
                  letterSpacing: 2,
                  shadows: const [
                    Shadow(
                      color: Colors.black12,
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Text(
                uiString(lang, 'one_pop_one_moment'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  color: Colors.white.withValues(alpha: 0.45),
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 80),

              _TapHint(lang: lang),
            ],
          ),
        ),
      ),
    );
  }
}

// Tap hint with fade animation
class _TapHint extends StatefulWidget {
  const _TapHint({required this.lang});
  final AppLanguage lang;

  @override
  State<_TapHint> createState() => _TapHintState();
}

class _TapHintState extends State<_TapHint>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )
      ..repeat(reverse: true);
    debugPrint('TapHint animation started — lang=${widget.lang}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.4 + (_controller.value * 0.25),
          child: Text(
            uiString(widget.lang, 'tap_to_enter'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        );
      },
    );
  }
}

