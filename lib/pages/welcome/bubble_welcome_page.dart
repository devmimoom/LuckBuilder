import 'dart:math';
import 'package:flutter/material.dart';

class BubbleWelcomePage extends StatefulWidget {
  const BubbleWelcomePage({super.key, required this.onFinished});
  final VoidCallback onFinished;

  @override
  State<BubbleWelcomePage> createState() => _BubbleWelcomePageState();
}

class _BubbleWelcomePageState extends State<BubbleWelcomePage>
    with TickerProviderStateMixin {
  late final List<AnimationController> _bubbleControllers;
  late final AnimationController _glowController;
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();

    // Floating bubbles (4 bubbles) - reduced for better performance and clearer visual
    _bubbleControllers = List.generate(
      4,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 18000 + (i * 3000)),
      )..repeat(),
    );

    // Center glow - subtle pulse
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);

    // Fade in animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    for (var controller in _bubbleControllers) {
      controller.dispose();
    }
    _glowController.dispose();
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
          child: Stack(
            children: [
              // Premium gradient background (fill so gradient has size)
              Positioned.fill(child: const _PremiumBackground()),

              // Floating bubbles (optimized)
              RepaintBoundary(
                child: _FloatingBubbles(controllers: _bubbleControllers),
              ),

              // Center glow
              RepaintBoundary(
                child: _CenterGlow(controller: _glowController),
              ),

              // Center content
              const _CenterContent(),
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
            Color(0xFF1A2642),
            Color(0xFF0F1629),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

// Floating bubbles - 4 bubbles, improved visibility
class _FloatingBubbles extends StatelessWidget {
  const _FloatingBubbles({required this.controllers});
  final List<AnimationController> controllers;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bubbles = [
      _BubbleData(size: 160, top: 0.15, left: 0.75, controller: controllers[0]),
      _BubbleData(size: 130, top: 0.25, left: 0.12, controller: controllers[1]),
      _BubbleData(size: 115, top: 0.72, left: 0.08, controller: controllers[2]),
      _BubbleData(size: 100, top: 0.78, left: 0.85, controller: controllers[3]),
    ];

    return Stack(
      children: bubbles
          .map((data) => _AnimatedBubble(data: data, screenSize: size))
          .toList(),
    );
  }
}

class _BubbleData {
  final double size;
  final double top;
  final double left;
  final AnimationController controller;

  _BubbleData({
    required this.size,
    required this.top,
    required this.left,
    required this.controller,
  });
}

class _AnimatedBubble extends StatelessWidget {
  const _AnimatedBubble({required this.data, required this.screenSize});
  final _BubbleData data;
  final Size screenSize;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: data.controller,
      builder: (context, child) {
        final t = data.controller.value;

        // Smooth floating movement
        final dx = sin(t * 2 * pi) * 10;
        final dy = -cos(t * 2 * pi) * 15;
        final scale = 1.0 + sin(t * 2 * pi) * 0.03;
        // Improved opacity for better visibility
        final opacity = 0.60 + sin(t * 2 * pi) * 0.08;

        return Positioned(
          top: screenSize.height * data.top + dy,
          left: screenSize.width * data.left + dx - data.size / 2,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: data.size,
                height: data.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF667EEA).withOpacity(0.6),
                      const Color(0xFF667EEA).withOpacity(0.35),
                      const Color(0xFF667EEA).withOpacity(0.12),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.35, 0.65, 1.0],
                  ),
                  border: Border.all(
                    color: const Color(0xFF667EEA).withOpacity(0.10),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Center glow - subtle pulse
class _CenterGlow extends StatelessWidget {
  const _CenterGlow({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final opacity = 0.10 + controller.value * 0.05;
          final scale = 1.0 + controller.value * 0.04;

          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF667EEA).withOpacity(0.3),
                      const Color(0xFF667EEA).withOpacity(0.15),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          );
        },
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
            children: [
              // Brand name - with shadow for better readability
              const Text(
                'OnePop',
                style: TextStyle(
                  fontSize: 48,
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
              const SizedBox(height: 12),

              // Tagline - subtle
              Text(
                'Your mental snack',
                style: TextStyle(
                  fontSize: 15,
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
                  fontSize: 13,
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
          opacity: 0.2 + (_controller.value * 0.2),
          child: Text(
            '點擊進入',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.5),
              letterSpacing: 1,
            ),
          ),
        );
      },
    );
  }
}

