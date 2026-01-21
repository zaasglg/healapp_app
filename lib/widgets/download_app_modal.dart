import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:ui';
// Conditional import for web
import 'dart:html' as html if (dart.library.io) 'dart:io';

/// Красивое модальное окно для предложения скачать приложение (только для веб-версии)
class DownloadAppModal extends StatelessWidget {
  const DownloadAppModal({super.key});

  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'download_app_modal_dismissed';

  /// Показывает модальное окно, если пользователь на веб-версии и еще не закрывал его
  static Future<void> showIfWeb(BuildContext context) async {
    if (!kIsWeb) return;

    // Проверяем, закрывал ли пользователь модалку ранее
    try {
      final dismissed = await _storage.read(key: _storageKey);
      if (dismissed == 'true') {
        return; // Пользователь уже закрыл модалку, не показываем снова
      }
    } catch (e) {
      // Если ошибка чтения, показываем модалку
    }

    // Небольшая задержка для лучшего UX
    await Future.delayed(const Duration(milliseconds: 800));

    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => const DownloadAppModal(),
    );
  }

  /// Сохраняет, что пользователь закрыл модалку
  static Future<void> _markAsDismissed() async {
    try {
      await _storage.write(key: _storageKey, value: 'true');
    } catch (e) {
      // Игнорируем ошибки записи
    }
  }

  /// Скачивает APK файл
  static void _downloadApk() {
    if (kIsWeb) {
      // Для веб-версии используем dart:html для создания ссылки на скачивание
      final anchor = html.AnchorElement(href: 'assets/app/app-release.apk')
        ..setAttribute('download', 'HealApp.apk')
        ..style.display = 'none';
      
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7DCAD6), Color(0xFF55ACBF), Color(0xFF4A9FB0)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF55ACBF).withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Декоративные элементы
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),

              // Основной контент
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 24),

                    // Заголовок
                    Text(
                      'Скачайте мобильное приложение',
                      style: GoogleFonts.firaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    // Описание
                    Text(
                      'Для лучшего опыта работы с дневником здоровья рекомендуем использовать мобильное приложение',
                      style: GoogleFonts.firaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.95),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 28),

                    // Преимущества
                    _buildFeature(
                      icon: Icons.notifications_active_rounded,
                      text: 'Push-уведомления о важных событиях',
                    ),
                    const SizedBox(height: 12),
                    _buildFeature(
                      icon: Icons.speed_rounded,
                      text: 'Быстрый доступ к функциям',
                    ),

                    const SizedBox(height: 32),

                    // Кнопка скачивания APK
                    _buildDownloadButton(
                      context,
                      'Скачать приложение',
                      Icons.download_rounded,
                      () async {
                        _downloadApk();
                        await _markAsDismissed();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Кнопка "Продолжить в браузере"
                    TextButton(
                      onPressed: () async {
                        await _markAsDismissed();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        'Продолжить в браузере',
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Кнопка закрытия
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  onPressed: () async {
                    await _markAsDismissed();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeature({required IconData icon, required String text}) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.firaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadButton(
    BuildContext context,
    String text,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF55ACBF), size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  style: GoogleFonts.firaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF55ACBF),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
