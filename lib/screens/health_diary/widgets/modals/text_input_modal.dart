/// Модальное окно с текстовым вводом
///
/// Используется для показателей, требующих текстового описания
/// (кормление, когнитивные игры и т.д.)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/app_config.dart';

/// Показать модальное окно текстового ввода
Future<String?> showTextInputModal({
  required BuildContext context,
  required String title,
  required String description,
  required String hint,
}) async {
  final controller = TextEditingController();

  return showDialog<String>(
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
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.firaSans(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppConfig.primaryColor),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
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
                    onPressed: () {
                      if (controller.text.isNotEmpty) {
                        Navigator.pop(ctx, controller.text);
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
