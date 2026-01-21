/// Сводка по маршрутному листу
///
/// Отображает статистику по выполнению задач.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/app_config.dart';

/// Данные статистики
class RouteSheetStats {
  final int total;
  final int completed;
  final int pending;
  final int missed;

  RouteSheetStats({
    this.total = 0,
    this.completed = 0,
    this.pending = 0,
    this.missed = 0,
  });

  double get completionPercent => total > 0 ? (completed / total * 100) : 0;
}

/// Сводка маршрутного листа
class RouteSheetSummary extends StatelessWidget {
  /// Статистика
  final RouteSheetStats stats;

  const RouteSheetSummary({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConfig.primaryColor.withOpacity(0.1),
            AppConfig.primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConfig.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Прогресс
          Row(
            children: [
              // Круговой прогресс
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: stats.completionPercent / 100,
                      strokeWidth: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppConfig.primaryColor,
                      ),
                    ),
                    Text(
                      '${stats.completionPercent.round()}%',
                      style: GoogleFonts.firaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppConfig.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Статистика
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Выполнение задач',
                      style: GoogleFonts.firaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stats.completed} из ${stats.total} задач',
                      style: GoogleFonts.firaSans(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Детальная статистика
          Row(
            children: [
              _StatItem(
                label: 'Выполнено',
                value: stats.completed,
                color: Colors.green,
              ),
              const SizedBox(width: 12),
              _StatItem(
                label: 'Ожидает',
                value: stats.pending,
                color: Colors.orange,
              ),
              const SizedBox(width: 12),
              _StatItem(
                label: 'Пропущено',
                value: stats.missed,
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: GoogleFonts.firaSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.firaSans(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
