import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/connection_state.dart';

/// Компактный график скорости (последние 60 секунд).
class TrafficChart extends StatelessWidget {
  const TrafficChart({super.key, required this.points, this.height = 88});

  final List<SpeedPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ChartPainter(points),
        child: points.isEmpty
            ? Center(
                child: Text(
                  '—',
                  style: TextStyle(
                    color: AuraColors.textFaint.withOpacity(0.5),
                    fontSize: 22,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.points);

  final List<SpeedPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final maxDown = points.map((p) => p.downBps).reduce((a, b) => a > b ? a : b);
    final maxUp = points.map((p) => p.upBps).reduce((a, b) => a > b ? a : b);
    final maxValue = [maxDown, maxUp, 1024.0].reduce((a, b) => a > b ? a : b);

    final stepX = size.width / (points.length - 1);

    Offset pointFor(int i, double value) {
      final x = i * stepX;
      final y = size.height - (value / maxValue) * (size.height * 0.92) - 4;
      return Offset(x, y);
    }

    void drawLine(
        double Function(SpeedPoint) selector, Color color, double opacity) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final o = pointFor(i, selector(points[i]));
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }

      final fill = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();

      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withOpacity(0.22 * opacity),
              color.withOpacity(0),
            ],
          ).createShader(Offset.zero & size),
      );

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = color.withOpacity(opacity),
      );
    }

    drawLine((p) => p.downBps, AuraColors.accent2, 1);
    drawLine((p) => p.upBps, AuraColors.accent, 0.85);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => true;
}
