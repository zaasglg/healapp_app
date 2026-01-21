/// Модальное окно выбора диапазона времени
///
/// Используется для показателей с диапазоном времени
/// (например, сон: начало - окончание)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/app_config.dart';
import 'time_picker_modal.dart';

/// Результат выбора диапазона времени
class TimeRangeResult {
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  TimeRangeResult({required this.startTime, required this.endTime});

  String get formattedRange {
    final start =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final end =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    return '$start — $end';
  }
}

/// Показать модальное окно выбора диапазона времени
Future<TimeRangeResult?> showTimeRangeModal({
  required BuildContext context,
  required String title,
  required String description,
}) async {
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  return showDialog<TimeRangeResult>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.firaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final time = await showTimePickerModal(
                          context: ctx,
                          title: 'Время начала',
                          description: 'Выберите время начала',
                          initialTime: startTime ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setModalState(() => startTime = time);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Начало',
                              style: GoogleFonts.firaSans(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              startTime != null
                                  ? startTime!.format(ctx)
                                  : '--:--',
                              style: GoogleFonts.firaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: startTime != null
                                    ? Colors.grey.shade900
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.arrow_forward, color: Colors.grey.shade400),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final time = await showTimePickerModal(
                          context: ctx,
                          title: 'Время окончания',
                          description: 'Выберите время окончания',
                          initialTime: endTime ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setModalState(() => endTime = time);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Окончание',
                              style: GoogleFonts.firaSans(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              endTime != null ? endTime!.format(ctx) : '--:--',
                              style: GoogleFonts.firaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: endTime != null
                                    ? Colors.grey.shade900
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        'Отмена',
                        style: GoogleFonts.firaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: startTime != null && endTime != null
                          ? () => Navigator.pop(
                              ctx,
                              TimeRangeResult(
                                startTime: startTime!,
                                endTime: endTime!,
                              ),
                            )
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConfig.primaryColor,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        'Сохранить',
                        style: GoogleFonts.firaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
