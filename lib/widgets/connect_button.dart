import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

enum ConnectButtonState { idle, connecting, connected }

/// Большая круглая кнопка подключения с анимацией «пульса».
class ConnectButton extends StatefulWidget {
  const ConnectButton({
    super.key,
    required this.state,
    required this.onTap,
  });

  final ConnectButtonState state;
  final VoidCallback onTap;

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _syncAnimations();
  }

  @override
  void didUpdateWidget(covariant ConnectButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimations();
  }

  void _syncAnimations() {
    switch (widget.state) {
      case ConnectButtonState.connected:
        _pulse.repeat(reverse: true);
        _spin.stop();
        break;
      case ConnectButtonState.connecting:
        _spin.repeat();
        _pulse.stop();
        break;
      case ConnectButtonState.idle:
        _pulse.stop();
        _spin.stop();
        break;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.state == ConnectButtonState.connected;
    final isConnecting = widget.state == ConnectButtonState.connecting;

    final gradient = isConnected
        ? AuraColors.connectedGradient
        : AuraColors.accentGradient;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _spin]),
        builder: (context, _) {
          final pulseT = Curves.easeInOut.transform(_pulse.value);
          return SizedBox(
            width: 236,
            height: 236,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Внешние кольца
                if (isConnected)
                  Transform.scale(
                    scale: 1.0 + pulseT * 0.12,
                    child: Container(
                      width: 236,
                      height: 236,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AuraColors.success.withOpacity(0.16 * (1 - pulseT)),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                if (isConnected)
                  Container(
                    width: 214,
                    height: 214,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AuraColors.success.withOpacity(0.25),
                        width: 1.5,
                      ),
                    ),
                  ),
                // Вращающееся кольцо при подключении
                if (isConnecting)
                  Transform.rotate(
                    angle: _spin.value * 2 * math.pi,
                    child: CustomPaint(
                      size: const Size(214, 214),
                      painter: _SpinnerRingPainter(),
                    ),
                  ),
                // Основной круг
                Container(
                  width: 186,
                  height: 186,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: gradient,
                    boxShadow: [
                      BoxShadow(
                        color: (isConnected ? AuraColors.success : AuraColors.accent)
                            .withOpacity(0.45),
                        blurRadius: 42,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        key: ValueKey(widget.state),
                        isConnected
                            ? Icons.power_settings_new_rounded
                            : isConnecting
                                ? Icons.sync_rounded
                                : Icons.power_settings_new_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SpinnerRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    paint.color = Colors.white.withOpacity(0.08);
    canvas.drawCircle(rect.center, size.width / 2, paint);

    paint.color = Colors.white.withOpacity(0.8);
    canvas.drawArc(
      Rect.fromCircle(center: rect.center, radius: size.width / 2),
      -math.pi / 2,
      math.pi * 1.1,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
