/// Компактная карточка закрепленного показателя
///
/// Отображает название показателя, текущее значение
/// и время до следующего заполнения.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'indicator_value_circle.dart';

/// Компактная карточка для списка закрепленных показателей
class IndicatorCard extends StatelessWidget {
  /// Название показателя
  final String name;

  /// Текущее значение
  final String? value;

  /// Текст времени до заполнения
  final String displayTime;

  /// Callback при нажатии кнопки "Заполнить"
  final VoidCallback onFillTap;

  /// Отступ справа
  final double marginRight;

  const IndicatorCard({
    super.key,
    required this.name,
    this.value,
    required this.displayTime,
    required this.onFillTap,
    this.marginRight = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = displayTime == 'Выберите время';

    return Container(
      height: 260,
      margin: EdgeInsets.only(right: marginRight),
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
            name,
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
          IndicatorValueCircle(value: value),
          const SizedBox(height: 8),
          Center(
            child: Text(
              displayTime,
              style: GoogleFonts.firaSans(
                fontSize: isEmpty ? 10 : 12,
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
              onPressed: onFillTap,
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
