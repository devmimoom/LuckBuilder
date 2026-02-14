import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onFinished,
        child: FadeTransition(
          opacity: _fadeController,
          child: const Stack(
            children: [
              Positioned.fill(child: _PremiumBackground()),
              _CenterContent(),
            ],
          ),
        ),
      ),
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
  const _CenterContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'OnePop',
                style: GoogleFonts.quicksand(
                  fontSize: 54,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                  letterSpacing: 6,
                  height: 1.1,
                  shadows: const [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Tagline - subtle
              Text(
                'Your mental snack',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.65),
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

              // Secondary tagline - very subtle
              Text(
                'One pop · One moment',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  color: Colors.white.withOpacity(0.45),
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 80),

              // Tap hint with subtle animation
              const _TapHint(),
            ],
          ),
        ),
      ),
    );
  }
}

// Tap hint with fade animation
class _TapHint extends StatefulWidget {
  const _TapHint();

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
    )..repeat(reverse: true);
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
          child: const Text(
            'Tap to enter',
            style: TextStyle(
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

