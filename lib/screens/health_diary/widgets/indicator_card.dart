import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../repositories/diary_repository.dart';
import '../utils/indicator_utils.dart';
import 'dashed_circle_painter.dart';

/// Карточка показателя в свёрнутом виде
class IndicatorCard extends StatelessWidget {
  final PinnedParameter parameter;
  final int index;
  final bool isLast;
  final VoidCallback onTap;

  const IndicatorCard({
    super.key,
    required this.parameter,
    required this.index,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      margin: EdgeInsets.only(right: isLast ? 0 : 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF61B4C6), Color(0xFF317799)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            getIndicatorLabel(parameter.key),
            style: GoogleFonts.firaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 70,
            height: 70,
            child: CustomPaint(
              size: const Size(50, 50),
              painter: const DashedCirclePainter(),
              child: Center(
                child: Container(width: 24, height: 2, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Выберите время',
              style: GoogleFonts.firaSans(
                fontSize: 10,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade800,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: onTap,
              child: Text(
                'Заполнить',
                style: GoogleFonts.firaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
