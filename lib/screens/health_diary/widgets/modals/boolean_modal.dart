/// Модальное окно с выбором "Было/Не было"
///
/// Используется для булевых показателей, где нужно
/// отметить факт события.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/app_config.dart';

/// Показать модальное окно выбора Было/Не было
Future<bool?> showBooleanModal({
  required BuildContext context,
  required String title,
  required String description,
}) async {
  bool? selectedValue;

  return showDialog<bool>(
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
              const SizedBox(height: 4),
              Text(
                'Время заполнения фиксируется автоматически',
                style: GoogleFonts.firaSans(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setModalState(() => selectedValue = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: selectedValue == true
                              ? AppConfig.primaryColor.withOpacity(0.1)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selectedValue == true
                                ? AppConfig.primaryColor
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Было',
                            style: GoogleFonts.firaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: selectedValue == true
                                  ? AppConfig.primaryColor
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setModalState(() => selectedValue = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: selectedValue == false
                              ? AppConfig.primaryColor.withOpacity(0.1)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selectedValue == false
                                ? AppConfig.primaryColor
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Не было',
                            style: GoogleFonts.firaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: selectedValue == false
                                  ? AppConfig.primaryColor
                                  : Colors.grey.shade700,
                            ),
                          ),
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
                      onPressed: selectedValue != null
                          ? () => Navigator.pop(ctx, selectedValue)
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
