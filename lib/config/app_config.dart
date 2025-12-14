import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Глобальная конфигурация приложения.
/// Содержит важные константы (например, главный цвет).
class AppConfig {
  // Основной (главный) цвет приложения. Изменяйте здесь.
  // Hex: #55ACBF
  static const Color primaryColor = Color(0xFF55ACBF);

  // Пример других настроек
  static const String appName = 'HealApp';
}

/// Тема приложения, основанная на значениях из [AppConfig].
class AppTheme {
  static ThemeData get theme => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: AppConfig.primaryColor),
    useMaterial3: true,
    textTheme: GoogleFonts.firaSansTextTheme(),
  );
}
