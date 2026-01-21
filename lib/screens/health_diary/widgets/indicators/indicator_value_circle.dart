/// Круг с пунктирной обводкой для отображения значения показателя
///
/// Используется в карточках закрепленных показателей
/// для визуального отображения текущего значения.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Виджет круга со значением показателя
class IndicatorValueCircle extends StatelessWidget {
  /// Значение для отображения
  final String? value;

  /// Размер круга
  final double size;

  const IndicatorValueCircle({super.key, this.value, this.size = 90});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size * 0.833, size * 0.833),
        painter: _DashedCirclePainter(),
        child: Center(
          child: value != null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    value!,
                    style: GoogleFonts.firaSans(
                      fontSize: size * 0.244,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                )
              : Container(width: size * 0.2, height: 2, color: Colors.white),
        ),
      ),
    );
  }
}

/// Custom painter для пунктирного круга
class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    // Рисуем круг с радиальным градиентом
    final gradient = RadialGradient(
      colors: [
        const Color(0xFFA0E7E5).withOpacity(0.3),
        const Color(0xFF61B4C6).withOpacity(0.2),
      ],
    );
    final circlePaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, circlePaint);

    // Рисуем пунктирную обводку
    final dashPaint = Paint()
      ..color = const Color(0xFFA0E7E5).withOpacity(0.6)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const dashCount = 20;
    const dashAngle = (2 * 3.14159) / dashCount;
    const dashLength = dashAngle * 0.4;

    for (int i = 0; i < dashCount; i++) {
      final angle = i * dashAngle;
      final startAngle = angle;
      final endAngle = angle + dashLength;

      final path = Path();
      path.addArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        endAngle - startAngle,
      );
      canvas.drawPath(path, dashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
