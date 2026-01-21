/// Модальное окно для ввода измерений
///
/// Используется для показателей с числовыми значениями
/// (температура, давление, пульс и т.д.)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/app_config.dart';

/// Результат ввода измерения
class MeasurementResult {
  final dynamic value;
  final String displayText;

  MeasurementResult({required this.value, required this.displayText});
}

/// Показать модальное окно ввода измерения
Future<MeasurementResult?> showMeasurementModal({
  required BuildContext context,
  required String title,
  required String description,
  required String unit,
  required String key,
}) async {
  final controller = TextEditingController();
  final controller2 = TextEditingController(); // Для давления
  final isBloodPressure = key == 'blood_pressure';

  return showDialog<MeasurementResult>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (ctx) => Dialog(
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
            const SizedBox(height: 4),
            Text(
              'Время заполнения фиксируется автоматически',
              style: GoogleFonts.firaSans(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            if (isBloodPressure) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Систолическое',
                        hintText: '120',
                        suffixText: 'мм',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppConfig.primaryColor),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '/',
                      style: GoogleFonts.firaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller2,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Диастолическое',
                        hintText: '80',
                        suffixText: 'мм',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppConfig.primaryColor),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  suffixText: unit,
                  suffixStyle: GoogleFonts.firaSans(
                    color: Colors.grey.shade600,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ],
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
                    onPressed: () {
                      if (isBloodPressure) {
                        if (controller.text.isEmpty ||
                            controller2.text.isEmpty) {
                          return;
                        }
                        final value = {
                          'systolic': int.tryParse(controller.text.trim()) ?? 0,
                          'diastolic':
                              int.tryParse(controller2.text.trim()) ?? 0,
                        };
                        Navigator.pop(
                          ctx,
                          MeasurementResult(
                            value: value,
                            displayText:
                                '${controller.text}/${controller2.text}',
                          ),
                        );
                      } else {
                        if (controller.text.isEmpty) return;
                        Navigator.pop(
                          ctx,
                          MeasurementResult(
                            value: controller.text,
                            displayText: '${controller.text} $unit',
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.primaryColor,
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
  );
}
