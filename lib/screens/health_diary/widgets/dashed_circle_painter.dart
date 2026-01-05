import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom painter для пунктирного круга
/// Используется для отображения индикатора на карточках показателей
class DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;
  final double gapRatio;

  const DashedCirclePainter({
    this.color = Colors.white,
    this.strokeWidth = 2.0,
    this.dashCount = 24,
    this.gapRatio = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2);

    // Рисуем пунктирный круг
    final dashAngle = (2 * math.pi) / dashCount;
    final gapAngle = dashAngle * gapRatio;
    final sweepAngle = dashAngle - gapAngle;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle - (math.pi / 2);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashCount != dashCount ||
        oldDelegate.gapRatio != gapRatio;
  }
}
