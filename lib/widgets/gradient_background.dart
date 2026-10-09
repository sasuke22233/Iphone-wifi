import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Фон приложения: глубокий градиент + мягкие «сияния».
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child, this.glow = true});

  final Widget child;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AuraColors.bgGradient),
      child: Stack(
        children: [
          if (glow) ...[
            const _Glow(
              color: Color(0x557C5CFF),
              size: 420,
              alignment: Alignment(-1.1, -1.0),
            ),
            const _Glow(
              color: Color(0x3300C2FF),
              size: 380,
              alignment: Alignment(1.2, -0.4),
            ),
            const _Glow(
              color: Color(0x222CE5A6),
              size: 420,
              alignment: Alignment(0.6, 1.35),
            ),
          ],
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.color,
    required this.size,
    required this.alignment,
  });

  final Color color;
  final double size;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: math.pi / 6,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [color, color.withOpacity(0)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
