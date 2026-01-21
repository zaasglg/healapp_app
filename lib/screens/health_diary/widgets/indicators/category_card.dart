/// Карточка категории показателей
///
/// Раскрывающаяся карточка с заголовком категории и списком
/// показателей внутри. Используется для группировки показателей
/// по категориям (уход, физические, выделения).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/app_config.dart';
import '../../../../utils/app_icons.dart';
import '../../../../utils/health_diary/indicator_utils.dart';

/// Карточка категории с раскрывающимся списком показателей
class CategoryCard extends StatelessWidget {
  /// Заголовок категории
  final String title;

  /// Список активных показателей
  final List<dynamic> indicators;

  /// Список fallback показателей для отображения
  final List<String> fallbackIndicators;

  /// Раскрыта ли карточка
  final bool isExpanded;

  /// Callback при нажатии на карточку
  final VoidCallback onToggle;

  /// Callback при выборе показателя
  final Function(String key, String label) onIndicatorTap;

  const CategoryCard({
    super.key,
    required this.title,
    required this.indicators,
    required this.fallbackIndicators,
    required this.isExpanded,
    required this.onToggle,
    required this.onIndicatorTap,
  });

  @override
  Widget build(BuildContext context) {
    // Используем активные показатели или fallback
    final displayIndicators = indicators.isNotEmpty
        ? indicators
        : fallbackIndicators;

    // Формируем подзаголовок из первых 3 показателей
    String subtitle;
    if (indicators.isEmpty) {
      subtitle = fallbackIndicators
          .take(3)
          .map((e) => getIndicatorLabel(e))
          .join(', ');
      if (fallbackIndicators.length > 3) {
        subtitle += ' и т.д.';
      }
    } else {
      subtitle = indicators
          .take(3)
          .map((e) => getIndicatorLabel(e.toString()))
          .join(', ');
      if (indicators.length > 3) {
        subtitle += ' и т.д.';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: Radius.circular(isExpanded ? 0 : 16),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.firaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.firaSans(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Transform.rotate(
                      angle: isExpanded ? 4.71239 : 1.5708,
                      child: Image.asset(
                        AppIcons.chevron_right,
                        width: 20,
                        height: 20,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Раскрывающееся содержимое
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: displayIndicators.length == 1 ? 1 : 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: displayIndicators.length == 1 ? 6 : 2.8,
                    ),
                    itemCount: displayIndicators.length,
                    itemBuilder: (context, index) {
                      final indicatorKey = displayIndicators[index].toString();
                      final label = getIndicatorLabel(indicatorKey);
                      final isActive = indicators.contains(indicatorKey);

                      return GestureDetector(
                        onTap: isActive
                            ? () => onIndicatorTap(indicatorKey, label)
                            : null,
                        child: Opacity(
                          opacity: isActive ? 1.0 : 0.4,
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppConfig.primaryColor.withOpacity(
                                  isActive ? 0.5 : 0.2,
                                ),
                                width: 2,
                              ),
                            ),
                            child: Text(
                              label,
                              style: GoogleFonts.firaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
