/// Модальное окно выбора цвета мочи
///
/// Используется для выбора цвета мочи из предопределённого списка.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/app_config.dart';
import '../../../../utils/health_diary/diary_constants.dart';

/// Показать модальное окно выбора цвета мочи
Future<String?> showUrineColorModal({
  required BuildContext context,
  required String title,
}) async {
  String? selectedColor;

  return showDialog<String>(
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
                'Выберите цвет мочи',
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: urineColors.map((color) {
                  final isSelected = selectedColor == color;
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedColor = color),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppConfig.primaryColor.withOpacity(0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppConfig.primaryColor
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        color,
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? AppConfig.primaryColor
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
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
                      onPressed: selectedColor != null
                          ? () => Navigator.pop(ctx, selectedColor)
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
