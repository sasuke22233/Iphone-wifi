import 'dart:ui';

import 'package:flutter/material.dart';

/// Карточка в стиле «матовое стекло».
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = 22,
    this.onTap,
    this.borderColor,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: gradient ??
                LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.09),
                    Colors.white.withOpacity(0.035),
                  ],
                ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.10),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );

    final withMargin =
        margin == null ? card : Padding(padding: margin!, child: card);

    if (onTap == null) return withMargin;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: withMargin,
    );
  }
}
