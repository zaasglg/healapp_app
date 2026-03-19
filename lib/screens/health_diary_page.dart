import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:healapp_mobile/core/logging/app_logger.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../config/app_config.dart';
import '../config/hint_ids.dart';
import '../core/network/api_exceptions.dart';
import '../utils/app_icons.dart';
import '../bloc/hint/hint_bloc.dart';
import '../bloc/hint/hint_event.dart';
import '../bloc/route_sheet/route_sheet_cubit.dart';
import '../bloc/route_sheet/route_sheet_state.dart';
import '../bloc/diary/diary_bloc.dart';
import '../bloc/diary/diary_event.dart';
import '../bloc/diary/diary_state.dart';

import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';
import '../repositories/diary_repository.dart';
import '../bloc/alarm/alarm_bloc.dart';
import '../bloc/alarm/alarm_event.dart';
import '../repositories/employee_repository.dart';
import '../repositories/invitation_repository.dart';
import '../repositories/organization_repository.dart';
import 'package:toastification/toastification.dart';

// Health Diary компоненты
import 'health_diary/tabs/alarm_tab.dart';
import 'health_diary/widgets/widgets.dart';
import 'health_diary/widgets/modals/modals.dart' as modals;
import 'health_diary/widgets/modals/time_picker_modal.dart';
import 'health_diary/components/components.dart';
// Скрываем TaskStatus из route_sheet, т.к. используем из route_sheet_state.dart
import '../utils/health_diary/health_diary_utils.dart' as diary_utils;

class HealthDiaryPage extends StatefulWidget {
  final int diaryId;
  final int patientId;
  final int initialTabIndex;
  final bool showDiaryIntroHint;

  const HealthDiaryPage({
    super.key,
    required this.diaryId,
    required this.patientId,
    this.initialTabIndex = 0,
    this.showDiaryIntroHint = false,
  });
  static const String routeName = '/health-diary';

  @override
  State<HealthDiaryPage> createState() => _HealthDiaryPageState();
}

class _HealthDiaryPageState extends State<HealthDiaryPage>
    with SingleTickerProviderStateMixin {
  late DateTime _selectedDate;

  // Animation controller for indicator expansion
  late AnimationController _indicatorAnimationController;
  late Animation<double> _indicatorExpandAnimation;

  // Diary tab state
  bool _isCareExpanded = false;
  bool _isPhysicalExpanded = false;
  bool _isExcretionExpanded = false;
  bool _isSymptomsExpanded = false;
  bool _isCustomIndicatorsExpanded = false;
  bool _isAccessManagementExpanded = false;
  bool _isHistoryDatePickerExpanded = false;
  bool _isRouteSheetDatePickerExpanded = false;
  int? _selectedIndicatorIndex;
  final Map<String, List<String>> _editedTimes = {};

  // Client invitation state
  String? _clientInviteUrl;
  bool _isCreatingInvitation = false;

  // Diary owner client state
  final DiaryRepository _diaryRepository = DiaryRepository();
  List<DiaryClient> _diaryOwnerClients = [];
  bool _isLoadingDiaryOwner = false;
  String? _diaryOwnerError;

  // Diary access management state
  final OrganizationRepository _organizationRepository =
      OrganizationRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  List<Map<String, dynamic>> _diaryAccessList = [];
  List<Employee> _allEmployees = [];
  bool _isLoadingAccess = false;

  // Timer for updating display time
  Timer? _displayTimeTimer;
  String? _pendingHintAfterCloseId;
  String? _pendingHintAfterCategoryExpandId;
  String? _activeAllIndicatorsCategoryHint;
  bool _shouldShowAllIndicatorsCareSaveHint = false;
  bool _isAllIndicatorsSavedHintVisible = false;
  Timer? _allIndicatorsSavedHintTimer;

  // Category indicator keys
  static const List<String> _careIndicatorKeys = [
    'walk',
    'cognitive_games',
    'diaper_change',
    'hygiene',
    'skin_moisturizing',
    'meal',
    'medication',
    'vitamins',
    'sleep',
  ];

  static const List<String> _physicalIndicatorKeys = [
    'temperature',
    'blood_pressure',
    'respiratory_rate',
    'pain_level',
    'oxygen_saturation',
    'blood_sugar',
  ];

  static const List<String> _excretionIndicatorKeys = ['urine', 'defecation'];

  static const List<String> _symptomIndicatorKeys = [
    'nausea',
    'dyspnea',
    'cough',
    'hiccup',
    'vomiting',
    'itching',
    'dry_mouth',
    'taste_disorder',
  ];

  String _getParameterType(String key) {
    const physicalKeys = [
      'blood_pressure',
      'temperature',
      'pulse',
      'blood_sugar',
      'weight',
      'oxygen_saturation',
      'urine_output',
      'fluid_intake',
    ];
    if (physicalKeys.contains(key)) return 'physical';
    return 'care';
  }

  List<String> _normalizeIndicatorKeys(dynamic rawIndicators) {
    if (rawIndicators == null) return [];

    if (rawIndicators is List) {
      return rawIndicators
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (rawIndicators is String) {
      final cleaned = rawIndicators.replaceAll('[', '').replaceAll(']', '');
      return cleaned
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return [];
  }

  String? _getLastValue(Diary? diary, String key) {
    if (diary == null) return null;
    // Фильтруем записи по ключу
    final entries = diary.entries.where((e) => e.parameterKey == key).toList();
    if (entries.isEmpty) return null;
    // Сортируем по дате (свежие первые)
    entries.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    // entry.value теперь Map<String,dynamic> — используем dynamic для совместимости
    dynamic value = entries.first.value;

    // Обработка Map значений (например, {value: "Парацетамол"})
    if (value is Map) {
      // Для давления
      if (key == 'blood_pressure') {
        log.d('_getLastValue: blood_pressure raw value = $value');
        dynamic bpValue = value;

        // Рекурсивно извлекаем вложенные значения {value: {value: {...}}}
        while (bpValue is Map &&
            bpValue.containsKey('value') &&
            bpValue['value'] is Map) {
          log.d('_getLastValue: unwrapping, current = $bpValue');
          bpValue = bpValue['value'];
        }

        log.d('_getLastValue: final bpValue = $bpValue');

        // Если после извлечения получили Map с ключом 'value' и строковым значением
        if (bpValue is Map &&
            bpValue.containsKey('value') &&
            bpValue['value'] is String) {
          final stringValue = bpValue['value'] as String;
          log.d('_getLastValue: Found string value: $stringValue');

          // Парсим строку формата "120/80 мм рт.ст." или "120/80"
          final match = RegExp(r'(\d+)/(\d+)').firstMatch(stringValue);
          if (match != null) {
            final systolic = int.tryParse(match.group(1) ?? '0') ?? 0;
            final diastolic = int.tryParse(match.group(2) ?? '0') ?? 0;
            log.d(
              '_getLastValue: Parsed from string: systolic=$systolic, diastolic=$diastolic',
            );

            if (systolic == 0 && diastolic == 0) {
              return '—';
            }
            return '$systolic/$diastolic';
          }
          // Если не удалось распарсить, возвращаем как есть без единиц измерения
          return stringValue.replaceAll(' мм рт.ст.', '').replaceAll(' мм', '');
        }

        // Теперь bpValue должен содержать {systolic: X, diastolic: Y} или {sys: X, dia: Y}
        if (bpValue is Map) {
          final systolic = bpValue['systolic'] ?? bpValue['sys'] ?? 0;
          final diastolic = bpValue['diastolic'] ?? bpValue['dia'] ?? 0;

          log.d('_getLastValue: systolic=$systolic, diastolic=$diastolic');

          // Если оба значения 0, возможно данные не были сохранены
          if (systolic == 0 && diastolic == 0) {
            log.w('_getLastValue: Both values are 0');
            return '—';
          }

          return '$systolic/$diastolic';
        }

        // Если после извлечения не Map, возвращаем прочерк
        return '—';
      }

      // Рекурсивное извлечение вложенного значения из цепочки {value: {value: {value: ...}}}
      while (value is Map && value.containsKey('value')) {
        value = value['value'];
      }

      // После извлечения проверяем финальный тип
      if (value is bool) {
        return value ? '✓' : '✗';
      }

      if (value is num) {
        if (value == 1) return '✓';
        if (value == 0) return '✗';
        return value.toString();
      }

      // Для Map после извлечения value - берём первое значение
      if (value is Map && value.isNotEmpty) {
        final firstValue = value.values.first;
        if (firstValue is bool) return firstValue ? '✓' : '✗';
        final textValue = firstValue?.toString() ?? '—';
        if (textValue.length > 12) {
          return '${textValue.substring(0, 10)}...';
        }
        return textValue;
      }

      // Для текстовых значений - ограничиваем длину для круга
      final textValue = value?.toString() ?? '—';
      if (textValue.length > 12) {
        return '${textValue.substring(0, 10)}...';
      }
      return textValue;
    }

    // Обработка строковых JSON-значений типа "{value: текст}"
    if (value is String && value.startsWith('{') && value.contains('value:')) {
      final regex = RegExp(r'\{value:\s*(.+?)\}');
      final match = regex.firstMatch(value);
      if (match != null && match.group(1) != null) {
        final extractedValue = match.group(1)!.trim();
        if (extractedValue.length > 12) {
          return '${extractedValue.substring(0, 10)}...';
        }
        return extractedValue;
      }
    }

    // Обработка булевых значений
    if (value is bool) {
      return value ? '✓' : '✗';
    }

    // Обработка числовых булевых представлений
    if (value is num) {
      if (value == 1) return '✓';
      if (value == 0) return '✗';
    }

    // Для остальных текстовых значений - ограничиваем длину
    final textValue = value?.toString() ?? '—';

    // Проверка на случайное отображение Map.toString()
    if (textValue.startsWith('{') && textValue.contains(':')) {
      return '—';
    }

    if (textValue.length > 12) {
      return '${textValue.substring(0, 10)}...';
    }
    return textValue;
  }

  Widget _buildIndicatorValueCircle(String? value) {
    // Определяем размер шрифта в зависимости от длины значения
    double fontSize = 22;
    if (value != null && value.length > 8) {
      fontSize = 16;
    } else if (value != null && value.length > 5) {
      fontSize = 20;
    }

    return SizedBox(
      width: 90,
      height: 90,
      child: CustomPaint(
        size: const Size(75, 75),
        painter: const DashedCirclePainter(),
        child: Center(
          child: value != null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    value,
                    style: GoogleFonts.firaSans(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                )
              : Container(width: 18, height: 2, color: Colors.white),
        ),
      ),
    );
  }

  /// Типы параметров для определения виджета ввода
  static const List<String> _booleanParams = [
    'skin_moisturizing',
    'hygiene',
    'defecation',
    'nausea',
    'vomiting',
    'dyspnea',
    'itching',
    'cough',
    'dry_mouth',
    'hiccup',
    'taste_disorder',
    'walk',
    'urine',
  ];

  static const List<String> _textParams = [
    'feeding',
    'cognitive_games',
    'medication',
    'vitamins',
    'meal',
  ];

  static const List<String> _measurementParams = [
    'blood_pressure',
    'temperature',
    'pulse',
    'saturation',
    'oxygen_saturation',
    'respiratory_rate',
    'pain_level',
    'sugar_level',
    'blood_sugar',
    'fluid_intake',
    'urine_output',
    'weight',
  ];

  /// Виджет ввода данных для закрепленного параметра
  Widget _buildParameterInputWidget({
    required PinnedParameter param,
    required TextEditingController measurementController,
    required BuildContext blocContext,
    required int index,
  }) {
    final key = param.key;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF7DCAD6), const Color(0xFF55ACBF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Заполните:',
            style: GoogleFonts.firaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          _buildInputForParameterType(
            key,
            measurementController,
            blocContext,
            index,
          ),
        ],
      ),
    );
  }

  /// Строит виджет ввода в зависимости от типа параметра
  Widget _buildInputForParameterType(
    String key,
    TextEditingController controller,
    BuildContext blocContext,
    int index,
  ) {
    // Булевые параметры — кнопки "Было" / "Не было"
    if (_booleanParams.contains(key)) {
      return ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, child) {
          final isTrue = value.text == 'true';
          final isFalse = value.text == 'false';

          return Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => controller.text = 'true',
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: isTrue
                            ? const LinearGradient(
                                colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isTrue
                            ? null
                            : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isTrue
                              ? const Color(0xFF43A047)
                              : Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: isTrue
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF66BB6A,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: isTrue ? Colors.white : Colors.grey.shade400,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Было',
                            style: GoogleFonts.firaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isTrue
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => controller.text = 'false',
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: isFalse
                            ? const LinearGradient(
                                colors: [Color(0xFFEF5350), Color(0xFFE53935)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isFalse
                            ? null
                            : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFalse
                              ? const Color(0xFFE53935)
                              : Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: isFalse
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFFEF5350,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cancel,
                            color: isFalse
                                ? Colors.white
                                : Colors.grey.shade400,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Не было',
                            style: GoogleFonts.firaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isFalse
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    // Текстовые параметры
    if (_textParams.contains(key)) {
      String hint = 'Введите текст';
      IconData icon = Icons.edit_note;

      if (key == 'medication' || key == 'vitamins') {
        hint = 'Название препарата';
        icon = Icons.medication;
      } else if (key == 'meal' || key == 'feeding') {
        hint = 'Что было съедено';
        icon = Icons.restaurant;
      } else if (key == 'cognitive_games') {
        hint = 'Описание активности';
        icon = Icons.psychology;
      }

      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: TextFormField(
          controller: controller,
          style: GoogleFonts.firaSans(
            fontSize: 15,
            color: Colors.grey.shade900,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.firaSans(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
            prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      );
    }

    // Параметры с измерениями
    String hint = 'Внесите замер';
    String? suffix;
    IconData icon = Icons.show_chart;
    TextInputType keyboardType = TextInputType.text;

    // Специальная обработка для давления - два поля
    if (key == 'blood_pressure') {
      // Создаём контроллер для диастолического если ещё нет
      if (!_diastolicControllers.containsKey(index)) {
        _diastolicControllers[index] = TextEditingController();
      }
      final diastolicController = _diastolicControllers[index]!;

      return Row(
        children: [
          // Систолическое давление
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.text,
                style: GoogleFonts.firaSans(
                  fontSize: 15,
                  color: Colors.grey.shade900,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: '120',
                  hintStyle: GoogleFonts.firaSans(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                  ),
                  prefixIcon: Icon(
                    Icons.favorite,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          // Разделитель /
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '/',
              style: GoogleFonts.firaSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          // Диастолическое давление
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: TextFormField(
                controller: diastolicController,
                keyboardType: TextInputType.text,
                style: GoogleFonts.firaSans(
                  fontSize: 15,
                  color: Colors.grey.shade900,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: '80',
                  hintStyle: GoogleFonts.firaSans(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                  ),
                  suffixText: 'мм',
                  suffixStyle: GoogleFonts.firaSans(
                    fontSize: 13,
                    color: const Color(0xFF61B4C6),
                    fontWeight: FontWeight.w600,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else if (key == 'temperature') {
      hint = '36.6';
      suffix = '°C';
      icon = Icons.thermostat;
      keyboardType = TextInputType.text;
    } else if (key == 'pulse') {
      hint = '70';
      suffix = 'уд/мин';
      icon = Icons.monitor_heart;
      keyboardType = TextInputType.text;
    } else if (key == 'saturation' || key == 'oxygen_saturation') {
      hint = '98';
      suffix = '%';
      icon = Icons.air;
      keyboardType = TextInputType.text;
    } else if (key == 'respiratory_rate') {
      hint = '16';
      suffix = 'вд/мин';
      icon = Icons.air;
      keyboardType = TextInputType.text;
    } else if (key == 'pain_level') {
      hint = '0-10';
      icon = Icons.sentiment_dissatisfied;
      keyboardType = TextInputType.text;
    } else if (key == 'sugar_level' || key == 'blood_sugar') {
      hint = '5.5';
      suffix = 'ммоль/л';
      icon = Icons.water_drop;
      keyboardType = TextInputType.text;
    } else if (key == 'fluid_intake' || key == 'urine_output') {
      hint = '250';
      suffix = 'мл';
      icon = Icons.local_drink;
      keyboardType = TextInputType.text;
    } else if (key == 'weight') {
      hint = '70';
      suffix = 'кг';
      icon = Icons.monitor_weight;
      keyboardType = TextInputType.text;
    } else if (key == 'diaper_change') {
      hint = 'Время смены';
      icon = Icons.baby_changing_station;
    } else if (key == 'sleep') {
      hint = 'Часов сна';
      icon = Icons.nightlight;
      keyboardType = TextInputType.text;
    }

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.firaSans(
          fontSize: 15,
          color: Colors.grey.shade900,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.firaSans(
            fontSize: 14,
            color: Colors.grey.shade400,
          ),
          prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
          suffixText: suffix,
          suffixStyle: GoogleFonts.firaSans(
            fontSize: 13,
            color: const Color(0xFF61B4C6),
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  int? _animatingFromIndex; // Used during animation

  final Map<int, TextEditingController> _measurementControllers = {};
  final Map<int, TextEditingController> _diastolicControllers =
      {}; // Для диастолического давления
  final Map<int, TextEditingController> _timeControllers = {};
  final Map<int, int> _fillCounts = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    // Initialize Russian locale
    initializeDateFormatting('ru', null);

    // Initialize animation controller with smooth duration
    _indicatorAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Use custom curve for very smooth and interesting animation
    _indicatorExpandAnimation = CurvedAnimation(
      parent: _indicatorAnimationController,
      curve: Curves.easeOutCubic,
    );

    // Start with animation completed so cards are visible
    _indicatorAnimationController.value = 1.0;

    // Start timer to update display time every minute
    _startDisplayTimeTimer();

    _loadDiaryOwnerClient();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.showDiaryIntroHint && !AppConfig.demoHintsAlwaysVisible) {
        return;
      }
      context.read<HintBloc>().add(
        const HintShowRequested(HintIds.healthDiaryIntro),
      );
    });
  }

  @override
  void dispose() {
    _displayTimeTimer?.cancel();
    _allIndicatorsSavedHintTimer?.cancel();
    _indicatorAnimationController.dispose();
    for (final controller in _measurementControllers.values) {
      controller.dispose();
    }
    for (final controller in _diastolicControllers.values) {
      controller.dispose();
    }
    for (final controller in _timeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Запускает таймер для обновления отображения времени каждую минуту
  void _startDisplayTimeTimer() {
    _displayTimeTimer?.cancel();

    // Вычисляем сколько секунд до следующей минуты
    final now = DateTime.now();
    final secondsUntilNextMinute = 60 - now.second;

    // Запускаем первое обновление через нужное количество секунд
    Timer(Duration(seconds: secondsUntilNextMinute), () {
      if (mounted) {
        setState(() {
          // Обновляем UI
        });

        // Затем запускаем периодический таймер каждую минуту
        _displayTimeTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
          if (mounted) {
            setState(() {
              // Обновляем UI каждую минуту
            });
          } else {
            timer.cancel();
          }
        });
      }
    });
  }

  void _dismissDiaryIntroHintIfVisible() {
    if (context.read<HintBloc>().state.isHintVisible(
      HintIds.healthDiaryIntro,
    )) {
      context.read<HintBloc>().add(
        const HintDismissRequested(HintIds.healthDiaryIntro),
      );
    }
  }

  void _dismissDiaryPinnedIndicatorsHintIfVisible() {
    if (context.read<HintBloc>().state.isHintVisible(
      HintIds.healthDiaryPinnedIndicators,
    )) {
      context.read<HintBloc>().add(
        const HintDismissRequested(HintIds.healthDiaryPinnedIndicators),
      );
    }
  }

  void _showDiaryPinnedIndicatorsHint() {
    context.read<HintBloc>().add(
      const HintShowRequested(HintIds.healthDiaryPinnedIndicators),
    );
  }

  void _dismissDiaryPinnedValueHintIfVisible() {
    if (context.read<HintBloc>().state.isHintVisible(
      HintIds.healthDiaryPinnedValue,
    )) {
      context.read<HintBloc>().add(
        const HintDismissRequested(HintIds.healthDiaryPinnedValue),
      );
    }
  }

  void _showDiaryPinnedValueHint() {
    context.read<HintBloc>().add(
      const HintShowRequested(HintIds.healthDiaryPinnedValue),
    );
  }

  void _dismissDiaryPinnedTimeHintIfVisible() {
    if (context.read<HintBloc>().state.isHintVisible(
      HintIds.healthDiaryPinnedTime,
    )) {
      context.read<HintBloc>().add(
        const HintDismissRequested(HintIds.healthDiaryPinnedTime),
      );
    }
  }

  void _showDiaryPinnedTimeHint() {
    context.read<HintBloc>().add(
      const HintShowRequested(HintIds.healthDiaryPinnedTime),
    );
  }

  void _dismissDiaryPinnedSaveHintIfVisible() {
    if (context.read<HintBloc>().state.isHintVisible(
      HintIds.healthDiaryPinnedSave,
    )) {
      context.read<HintBloc>().add(
        const HintDismissRequested(HintIds.healthDiaryPinnedSave),
      );
    }
  }

  void _showDiaryPinnedSaveHint() {
    context.read<HintBloc>().add(
      const HintShowRequested(HintIds.healthDiaryPinnedSave),
    );
  }

  void _dismissDiaryAllIndicatorsHintIfVisible() {
    if (context.read<HintBloc>().state.isHintVisible(
      HintIds.healthDiaryAllIndicators,
    )) {
      context.read<HintBloc>().add(
        const HintDismissRequested(HintIds.healthDiaryAllIndicators),
      );
    }
  }

  void _dismissDiaryAllIndicatorsSelectHintIfVisible() {
    if (context.read<HintBloc>().state.isHintVisible(
      HintIds.healthDiaryAllIndicatorsSelect,
    )) {
      context.read<HintBloc>().add(
        const HintDismissRequested(HintIds.healthDiaryAllIndicatorsSelect),
      );
    }
  }

  void _showDiaryAllIndicatorsSelectHint(String categoryId) {
    _activeAllIndicatorsCategoryHint = categoryId;
    _shouldShowAllIndicatorsCareSaveHint = categoryId == 'care';
    context.read<HintBloc>().add(
      const HintShowRequested(HintIds.healthDiaryAllIndicatorsSelect),
    );
  }

  void _dismissDiaryPinnedFillHintsIfVisible() {
    _dismissDiaryPinnedValueHintIfVisible();
    _dismissDiaryPinnedTimeHintIfVisible();
    _dismissDiaryPinnedSaveHintIfVisible();
  }

  void _toggleCategoryAndShowHintIfNeeded({
    required String categoryId,
    required bool isExpanded,
    required VoidCallback toggle,
  }) {
    final shouldShowHint =
        !isExpanded &&
        _pendingHintAfterCategoryExpandId ==
            HintIds.healthDiaryAllIndicatorsSelect;

    setState(toggle);

    if (shouldShowHint) {
      _pendingHintAfterCategoryExpandId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showDiaryAllIndicatorsSelectHint(categoryId);
      });
    }
  }

  void _showAllIndicatorsSavedHint() {
    _allIndicatorsSavedHintTimer?.cancel();

    if (mounted) {
      setState(() {
        _isAllIndicatorsSavedHintVisible = false;
      });
    }

    _allIndicatorsSavedHintTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;

      setState(() {
        _isAllIndicatorsSavedHintVisible = true;
      });

      _allIndicatorsSavedHintTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() {
          _isAllIndicatorsSavedHintVisible = false;
        });
      });
    });
  }

  void _handleAllIndicatorTap(
    BuildContext context, {
    required String categoryId,
    required String indicatorKey,
    required String label,
  }) {
    final shouldShowCareSaveHint =
        categoryId == 'care' && _shouldShowAllIndicatorsCareSaveHint;

    _shouldShowAllIndicatorsCareSaveHint = false;
    _dismissDiaryAllIndicatorsSelectHintIfVisible();
    _activeAllIndicatorsCategoryHint = null;

    _showIndicatorModal(
      context,
      indicatorKey,
      label,
      showAllIndicatorsCareSaveHint: shouldShowCareSaveHint,
    );
  }

  void _handleDiaryIntroConfirm(Diary? diary) {
    _dismissDiaryIntroHintIfVisible();
    if ((diary?.pinnedParameters ?? const []).isNotEmpty) {
      _showDiaryPinnedIndicatorsHint();
    }
  }

  /// Загрузка списка доступов к дневнику
  Future<void> _loadDiaryAccess() async {
    if (_isLoadingAccess) {
      return;
    }

    setState(() {
      _isLoadingAccess = true;
    });

    try {
      final accessList = await _organizationRepository.getDiaryAccessList(
        diaryId: widget.diaryId,
      );
      final employees = await _employeeRepository.getEmployees();

      if (mounted) {
        setState(() {
          _diaryAccessList = accessList;
          _allEmployees = employees;
          _isLoadingAccess = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAccess = false;
        });
      }
    }
  }

  /// Загрузка владельца дневника (клиента)
  Future<void> _loadDiaryOwnerClient() async {
    if (_isLoadingDiaryOwner) {
      return;
    }

    setState(() {
      _isLoadingDiaryOwner = true;
      _diaryOwnerError = null;
    });

    try {
      final clients = await _diaryRepository.getDiaryClients(widget.diaryId);
      if (mounted) {
        setState(() {
          _diaryOwnerClients = clients;
          _isLoadingDiaryOwner = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDiaryOwner = false;
          _diaryOwnerError = e.toString();
        });
      }
    }
  }

  /// Назначение доступа к дневнику
  Future<void> _assignDiaryAccess(Employee employee) async {
    // Используем user_id если есть, иначе id сотрудника
    final userId = employee.userId ?? employee.id;

    try {
      await _organizationRepository.assignDiaryAccess(
        patientId: widget.patientId,
        userId: userId,
      );

      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.flat,
          title: Text('Доступ предоставлен'),
          description: Text('${employee.fullName} получил доступ к дневнику'),
          autoCloseDuration: const Duration(seconds: 3),
        );

        // Перезагружаем список доступов
        _loadDiaryAccess();
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          title: Text('Ошибка'),
          description: Text('Не удалось предоставить доступ: $e'),
          autoCloseDuration: const Duration(seconds: 5),
        );
      }
    }
  }

  /// Отзыв доступа к дневнику
  Future<void> _revokeDiaryAccess(int userId, String employeeName) async {
    try {
      await _organizationRepository.revokeDiaryAccess(
        patientId: widget.patientId,
        userId: userId,
      );

      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.flat,
          title: Text('Доступ отозван'),
          description: Text('$employeeName больше не имеет доступа'),
          autoCloseDuration: const Duration(seconds: 3),
        );

        // Перезагружаем список доступов
        _loadDiaryAccess();
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          title: Text('Ошибка'),
          description: Text('Не удалось отозвать доступ'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  /// Показать диалог выбора сотрудника для предоставления доступа
  void _showAddAccessDialog() async {
    // Если сотрудники ещё не загружены, загружаем их
    if (_allEmployees.isEmpty) {
      setState(() {
        _isLoadingAccess = true;
      });

      try {
        final employees = await _employeeRepository.getEmployees();
        if (mounted) {
          setState(() {
            _allEmployees = employees;
            _isLoadingAccess = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoadingAccess = false;
          });
          toastification.show(
            context: context,
            type: ToastificationType.error,
            style: ToastificationStyle.flat,
            title: Text('Ошибка'),
            description: Text('Не удалось загрузить список сотрудников'),
            autoCloseDuration: const Duration(seconds: 3),
          );
        }
        return;
      }
    }

    // Фильтруем сотрудников, у которых уже есть доступ (по id из списка доступов)
    final existingUserIds = _diaryAccessList
        .map((a) => a['id'] as int?)
        .whereType<int>()
        .toSet();

    // Показываем сотрудников с user_id, которых ещё нет в списке доступов
    final availableEmployees = _allEmployees
        .where((e) => e.userId != null && !existingUserIds.contains(e.userId))
        .toList();

    // Если у сотрудников нет user_id, показываем всех (используем id как fallback)
    final employeesToShow = availableEmployees.isNotEmpty
        ? availableEmployees
        : _allEmployees
              .where((e) => !existingUserIds.contains(e.userId ?? e.id))
              .toList();

    if (employeesToShow.isEmpty && _allEmployees.isNotEmpty) {
      toastification.show(
        context: context,
        type: ToastificationType.info,
        style: ToastificationStyle.flat,
        title: Text('Нет доступных сотрудников'),
        description: Text('Все сотрудники уже имеют доступ к дневнику'),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }

    if (employeesToShow.isEmpty) {
      toastification.show(
        context: context,
        type: ToastificationType.info,
        style: ToastificationStyle.flat,
        title: Text('Нет сотрудников'),
        description: Text('В организации нет сотрудников для добавления'),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Выберите сотрудника',
                style: GoogleFonts.firaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: employeesToShow.length,
                itemBuilder: (context, index) {
                  final employee = employeesToShow[index];
                  // Для организаций показываем телефон, для сотрудников - роль
                  final subtitle = employee.isOrganization
                      ? (employee.phone ?? 'Организация')
                      : employee.roleDisplayName;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppConfig.primaryColor.withValues(
                        alpha: 0.1,
                      ),
                      backgroundImage: employee.avatarUrl != null
                          ? NetworkImage(employee.avatarUrl!)
                          : null,
                      child: employee.avatarUrl == null
                          ? Text(
                              employee.fullName.isNotEmpty
                                  ? employee.fullName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: AppConfig.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      employee.fullName,
                      style: GoogleFonts.firaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      subtitle,
                      style: GoogleFonts.firaSans(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _assignDiaryAccess(employee);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Выбрать показатель с анимацией (одновременно)
  void _selectIndicator(int index) {
    if (!_measurementControllers.containsKey(index)) {
      _measurementControllers[index] = TextEditingController();
      _timeControllers[index] = TextEditingController();
      _fillCounts[index] = 0;
    }

    // Сразу устанавливаем индексы и запускаем анимацию
    setState(() {
      _animatingFromIndex = _selectedIndicatorIndex;
      _selectedIndicatorIndex = index;
    });

    // Сбрасываем и запускаем анимацию
    _indicatorAnimationController.reset();
    _indicatorAnimationController.forward().then((_) {
      setState(() {
        _animatingFromIndex = null;
      });

      if (mounted && _selectedIndicatorIndex == index) {
        _showDiaryPinnedValueHint();
      }
    });
  }

  /// Закрыть раскрытую карточку с анимацией (одновременно)
  void _closeIndicator() {
    final closingIndex = _selectedIndicatorIndex;
    _dismissDiaryPinnedFillHintsIfVisible();

    setState(() {
      _animatingFromIndex = closingIndex;
      _selectedIndicatorIndex = null;
      _editedTimes.clear();
    });

    _indicatorAnimationController.reset();
    _indicatorAnimationController.forward().then((_) {
      final pendingHintId = _pendingHintAfterCloseId;
      _pendingHintAfterCloseId = null;

      setState(() {
        _animatingFromIndex = null;
      });

      // Принудительно обновляем UI еще раз через небольшую задержку
      // чтобы убедиться что время отображается правильно
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            // Принудительное обновление для корректного отображения времени
          });
        }
      });

      if (mounted && pendingHintId != null) {
        context.read<HintBloc>().add(HintShowRequested(pendingHintId));
      }
    });
  }

  /// Получить текст таймера до следующего заполнения
  String _getDisplayTime(List<String> times) {
    if (times.isEmpty) return 'Выберите время';

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final currentSeconds = now.second;

    final sortedTimes = List<String>.from(times)..sort();

    int? nextTimeMinutes;

    // Ищем ближайшее время сегодня
    for (final time in sortedTimes) {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final tMinutes = hour * 60 + minute;

      // Включаем текущую минуту, если секунды меньше 50
      // Это даёт время пользователю увидеть "через 0:00" перед срабатыванием
      if (tMinutes > currentMinutes ||
          (tMinutes == currentMinutes && currentSeconds < 50)) {
        nextTimeMinutes = tMinutes;
        break;
      }
    }

    int diffMinutes;

    if (nextTimeMinutes != null) {
      // Время сегодня
      diffMinutes = nextTimeMinutes - currentMinutes;
    } else {
      // Берем первое время завтра
      final firstParts = sortedTimes.first.split(':');
      final firstMinutes =
          int.parse(firstParts[0]) * 60 + int.parse(firstParts[1]);
      diffMinutes = (24 * 60 - currentMinutes) + firstMinutes;
    }

    final hours = diffMinutes ~/ 60;
    final minutes = diffMinutes % 60;

    if (diffMinutes == 0) {
      return 'Заполнить сейчас!';
    } else {
      return 'Заполнить через: ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    }
  }

  /// Build expandable category card for indicators
  Widget _buildCategoryCard({
    required String categoryId,
    required String title,
    required List<dynamic> indicators,
    required List<String> fallbackIndicators,
    required bool isExpanded,
    required VoidCallback onToggle,
    required BuildContext context,
  }) {
    // Use actual indicators if available, otherwise use fallback for subtitle
    final displayIndicators = indicators.isNotEmpty
        ? indicators
        : fallbackIndicators;

    // Build subtitle from first 3 indicators
    String subtitle;
    if (indicators.isEmpty) {
      subtitle = fallbackIndicators
          .take(3)
          .map((e) => _getIndicatorLabel(e))
          .join(', ');
      if (fallbackIndicators.length > 3) {
        subtitle += ' и т.д.';
      }
    } else {
      subtitle = indicators
          .take(3)
          .map((e) => _getIndicatorLabel(e.toString()))
          .join(', ');
      if (indicators.length > 3) {
        subtitle += ' и т.д.';
      }
    }

    final expandedContent = Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
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
              final label = _getIndicatorLabel(indicatorKey);
              final isActive = indicators.contains(indicatorKey);

              return GestureDetector(
                onTap: isActive
                    ? () => _handleAllIndicatorTap(
                        context,
                        categoryId: categoryId,
                        indicatorKey: indicatorKey,
                        label: label,
                      )
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
                        color: AppConfig.primaryColor.withValues(
                          alpha: isActive ? 0.5 : 0.2,
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
    );

    final shouldShowExpandedHint =
        _activeAllIndicatorsCategoryHint == categoryId;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
          // Expanded content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: expandedContent,
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hintState = context.watch<HintBloc>().state;
    final activeHintId = hintState.activeHintId;
    final isDiaryIntroHintVisible = hintState.isHintVisible(
      HintIds.healthDiaryIntro,
    );
    final isDiaryPinnedIndicatorsHintVisible = hintState.isHintVisible(
      HintIds.healthDiaryPinnedIndicators,
    );
    final isDiaryAllIndicatorsHintVisible = hintState.isHintVisible(
      HintIds.healthDiaryAllIndicators,
    );
    final isDiaryAllIndicatorsSelectHintVisible = hintState.isHintVisible(
      HintIds.healthDiaryAllIndicatorsSelect,
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => DiaryBloc()..add(LoadDiary(widget.diaryId)),
        ),
        BlocProvider(
          create: (context) =>
              RouteSheetCubit(patientId: widget.patientId)
                ..loadRouteSheet(date: _selectedDate),
        ),
        BlocProvider(
          create: (context) => AlarmBloc()..add(LoadAlarms(widget.diaryId)),
        ),
      ],
      child: BlocBuilder<DiaryBloc, DiaryState>(
        builder: (context, diaryState) {
          // Показываем загрузку
          if (diaryState is DiaryLoading) {
            return Scaffold(
              backgroundColor: const Color(0xFFF7F7F8),
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: Image.asset(
                    AppIcons.back,
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                  onPressed: () => context.pop(),
                ),
                title: Text(
                  'Дневник здоровья',
                  style: GoogleFonts.firaSans(
                    color: Colors.grey.shade900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          // Показываем ошибку
          if (diaryState is DiaryError) {
            return Scaffold(
              backgroundColor: const Color(0xFFF7F7F8),
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: Image.asset(
                    AppIcons.back,
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                  onPressed: () => context.pop(),
                ),
                title: Text(
                  'Дневник здоровья',
                  style: GoogleFonts.firaSans(
                    color: Colors.grey.shade900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      diaryState.message,
                      style: GoogleFonts.firaSans(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        context.read<DiaryBloc>().add(
                          LoadDiary(widget.diaryId),
                        );
                      },
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Получаем дневник
          final diary = diaryState is DiaryLoaded
              ? diaryState.diary
              : diaryState is DiaryParametersUpdated
              ? diaryState.diary
              : null;

          return BlocBuilder<AuthBloc, AuthState>(
            builder: (context, authState) {
              // Определяем, является ли пользователь сиделкой
              final isOrganizationCaregiver =
                  authState is AuthAuthenticated &&
                  authState.user.hasRole('caregiver');
              final isClientCaregiver =
                  authState is AuthAuthenticated &&
                  authState.user.accountType == 'client' &&
                  authState.user.hasRole('caregiver');
              // Проверка на account_type doctor и caregiver
              final isDoctorOrCaregiver =
                  authState is AuthAuthenticated &&
                  (authState.user.accountType == 'doctor' ||
                      authState.user.accountType == 'caregiver');

              final isCaregiver =
                  isOrganizationCaregiver ||
                  isClientCaregiver ||
                  isDoctorOrCaregiver;

              // Длина контроллера зависит от роли: 4 для сиделок, 5 для остальных
              final tabLength = isCaregiver ? 4 : 5;

              final showPinnedIndicatorsHint =
                  isDiaryPinnedIndicatorsHintVisible &&
                  diary != null &&
                  diary.pinnedParameters.isNotEmpty &&
                  widget.initialTabIndex == 0;
              final showPinnedFillHint =
                  _selectedIndicatorIndex != null &&
                  widget.initialTabIndex == 0 &&
                  (activeHintId == HintIds.healthDiaryPinnedValue ||
                      activeHintId == HintIds.healthDiaryPinnedTime ||
                      activeHintId == HintIds.healthDiaryPinnedSave);
              final showAllIndicatorsHint =
                  isDiaryAllIndicatorsHintVisible &&
                  _selectedIndicatorIndex == null &&
                  widget.initialTabIndex == 0;
              final showAllIndicatorsSelectHint =
                  isDiaryAllIndicatorsSelectHintVisible &&
                  _activeAllIndicatorsCategoryHint != null &&
                  _selectedIndicatorIndex == null &&
                  widget.initialTabIndex == 0;

              return DefaultTabController(
                length: tabLength,
                initialIndex: widget.initialTabIndex,
                child: Stack(
                  children: [
                    Scaffold(
                      backgroundColor: const Color(0xFFF7F7F8),
                      appBar: AppBar(
                        backgroundColor: Colors.white,
                        elevation: 0,
                        leading: IconButton(
                          icon: Image.asset(
                            AppIcons.back,
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                          ),
                          onPressed: () => context.pop(),
                        ),
                        title: Text(
                          diary?.patientName ?? 'Дневник здоровья',
                          style: GoogleFonts.firaSans(
                            color: Colors.grey.shade900,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        bottom: PreferredSize(
                          preferredSize: const Size.fromHeight(48),
                          child: Container(
                            color: Colors.white,
                            child: BlocBuilder<AuthBloc, AuthState>(
                              builder: (context, authState) {
                                final isOrganizationCaregiver =
                                    authState is AuthAuthenticated &&
                                    authState.user.hasRole('caregiver');
                                final isClientCaregiver =
                                    authState is AuthAuthenticated &&
                                    authState.user.accountType == 'client' &&
                                    authState.user.hasRole('caregiver');
                                final isDoctorOrCaregiver =
                                    authState is AuthAuthenticated &&
                                    (authState.user.accountType == 'doctor' ||
                                        authState.user.accountType ==
                                            'caregiver');

                                final isCaregiver =
                                    isOrganizationCaregiver ||
                                    isClientCaregiver ||
                                    isDoctorOrCaregiver;

                                final tabs = [
                                  const Tab(text: 'Дневник'),
                                  const Tab(text: 'Будильник'),
                                  const Tab(text: 'История'),
                                  const Tab(text: 'Маршрутный лист'),
                                  if (!isCaregiver) const Tab(text: 'Клиент'),
                                ];

                                return Stack(
                                  children: [
                                    TabBar(
                                      isScrollable: true,
                                      padding: const EdgeInsets.only(
                                        left: 16,
                                        right: 32,
                                      ),
                                      tabAlignment: TabAlignment.start,
                                      indicatorColor: AppConfig.primaryColor,
                                      indicatorWeight: 2,
                                      labelColor: Colors.grey.shade900,
                                      unselectedLabelColor:
                                          Colors.grey.shade600,
                                      labelStyle: GoogleFonts.firaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      unselectedLabelStyle:
                                          GoogleFonts.firaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                          ),
                                      tabs: tabs,
                                    ),
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      bottom: 0,
                                      child: IgnorePointer(
                                        child: Container(
                                          width: 48,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                              colors: [
                                                Colors.white.withOpacity(0.0),
                                                Colors.white,
                                              ],
                                              stops: const [0.0, 0.4],
                                            ),
                                          ),
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: Icon(
                                                Icons.chevron_right,
                                                color: Colors.black,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      body: BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, authState) {
                          final isOrganizationCaregiver =
                              authState is AuthAuthenticated &&
                              authState.user.hasRole('caregiver');
                          final isClientCaregiver =
                              authState is AuthAuthenticated &&
                              authState.user.accountType == 'client' &&
                              authState.user.hasRole('caregiver');
                          final isDoctorOrCaregiver =
                              authState is AuthAuthenticated &&
                              (authState.user.accountType == 'doctor' ||
                                  authState.user.accountType == 'caregiver');
                          final isCaregiver =
                              isOrganizationCaregiver ||
                              isClientCaregiver ||
                              isDoctorOrCaregiver;

                          final tabViews = [
                            _buildDiaryTab(context, diary),
                            _buildAlarmTab(context),
                            _buildHistoryTab(context, diary),
                            _buildRouteSheetTab(context),
                            if (!isCaregiver) _buildClientTab(context),
                          ];

                          return TabBarView(children: tabViews);
                        },
                      ),
                    ),
                    if (isDiaryIntroHintVisible &&
                        diary != null &&
                        widget.initialTabIndex == 0)
                      _HealthDiaryHintOverlay(
                        child: _HealthDiaryIntroTooltip(
                          onConfirm: () => _handleDiaryIntroConfirm(diary),
                        ),
                      ),
                    if (_isAllIndicatorsSavedHintVisible &&
                        widget.initialTabIndex == 0)
                      const _HealthDiaryTopSuccessOverlay(
                        child: _HealthDiarySavedTooltip(),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDiaryTab(BuildContext context, Diary? diary) {
    final pinnedParameters = diary?.pinnedParameters ?? [];
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          context.read<DiaryBloc>().add(LoadDiary(widget.diaryId));
          // Ждём пока состояние изменится
          await Future.delayed(const Duration(milliseconds: 500));
        },
        color: AppConfig.primaryColor,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Закрепленные показатели',
                          style: GoogleFonts.firaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedBuilder(
                          animation: _indicatorAnimationController,
                          builder: (context, child) {
                            final animValue = _indicatorExpandAnimation.value;
                            final isExpanding = _selectedIndicatorIndex != null;
                            final isClosing =
                                !isExpanding && _animatingFromIndex != null;

                            final fadeCurve = Curves.easeOut;
                            final slideCurve = Curves.easeInOutCubic;
                            final scaleCurve = Curves.easeOutBack;

                            final fadeProgress = fadeCurve.transform(animValue);
                            final slideProgress = slideCurve.transform(
                              animValue,
                            );
                            final scaleProgress = scaleCurve.transform(
                              animValue,
                            );

                            if (_animatingFromIndex != null ||
                                (isExpanding && animValue < 1.0)) {
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  if (pinnedParameters.isNotEmpty)
                                    Opacity(
                                      opacity: isExpanding
                                          ? (1.0 - fadeProgress).clamp(0.0, 1.0)
                                          : fadeProgress.clamp(0.0, 1.0),
                                      child: Transform.translate(
                                        offset: Offset(
                                          isExpanding
                                              ? slideProgress * 80
                                              : (1.0 - slideProgress) * 80,
                                          0,
                                        ),
                                        child: Transform.scale(
                                          scale: isExpanding
                                              ? 1.0 - (fadeProgress * 0.15)
                                              : 0.85 + (fadeProgress * 0.15),
                                          alignment: Alignment.center,
                                          child: Row(
                                            children: List.generate(pinnedParameters.length, (
                                              index,
                                            ) {
                                              final param =
                                                  pinnedParameters[index];
                                              return Expanded(
                                                child: Container(
                                                  height: 260,
                                                  margin: EdgeInsets.only(
                                                    right:
                                                        index <
                                                            pinnedParameters
                                                                    .length -
                                                                1
                                                        ? 8
                                                        : 0,
                                                  ),
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        const Color(0xFF61B4C6),
                                                        const Color(0xFF317799),
                                                      ],
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(
                                                              0.06 *
                                                                  (1.0 -
                                                                      fadeProgress),
                                                            ),
                                                        blurRadius: 12,
                                                        offset: const Offset(
                                                          0,
                                                          4,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        _getIndicatorLabel(
                                                          param.key,
                                                        ),
                                                        style:
                                                            GoogleFonts.firaSans(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                        textAlign:
                                                            TextAlign.center,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      _buildIndicatorValueCircle(
                                                        _getLastValue(
                                                          diary,
                                                          param.key,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      Center(
                                                        child: Text(
                                                          _getDisplayTime(
                                                            _editedTimes[param
                                                                    .key] ??
                                                                param.times,
                                                          ),
                                                          style:
                                                              GoogleFonts.firaSans(
                                                                fontSize: 11,
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ),
                                                          textAlign:
                                                              TextAlign.center,
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: double.infinity,
                                                        child: ElevatedButton(
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                Colors
                                                                    .grey
                                                                    .shade800,
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  vertical: 8,
                                                                ),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                            ),
                                                            elevation: 0,
                                                          ),
                                                          onPressed: () =>
                                                              _selectIndicator(
                                                                index,
                                                              ),
                                                          child: Text(
                                                            'Заполнить',
                                                            style:
                                                                GoogleFonts.firaSans(
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (isExpanding || isClosing)
                                    Opacity(
                                      opacity: isExpanding
                                          ? fadeProgress.clamp(0.0, 1.0)
                                          : (1.0 - fadeProgress).clamp(
                                              0.0,
                                              1.0,
                                            ),
                                      child: Transform.translate(
                                        offset: Offset(
                                          isExpanding
                                              ? -100 * (1.0 - slideProgress)
                                              : -100 * slideProgress,
                                          0,
                                        ),
                                        child: Transform.scale(
                                          scale: isExpanding
                                              ? 0.7 + (scaleProgress * 0.3)
                                              : 1.0 - (scaleProgress * 0.3),
                                          alignment: Alignment.centerLeft,
                                          child: Transform.rotate(
                                            angle: isExpanding
                                                ? (1.0 - scaleProgress) * 0.05
                                                : scaleProgress * 0.05,
                                            alignment: Alignment.centerLeft,
                                            child: _buildExpandedIndicatorCard(
                                              context,
                                              isExpanding
                                                  ? _selectedIndicatorIndex!
                                                  : _animatingFromIndex!,
                                              pinnedParameters,
                                              diary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }

                            if (_selectedIndicatorIndex != null) {
                              return _buildExpandedIndicatorCard(
                                context,
                                _selectedIndicatorIndex!,
                                pinnedParameters,
                                diary,
                              );
                            } else if (pinnedParameters.isNotEmpty) {
                              return Row(
                                children: List.generate(
                                  pinnedParameters.length,
                                  (index) {
                                    final param = pinnedParameters[index];
                                    return Expanded(
                                      child: Container(
                                        height: 260,
                                        margin: EdgeInsets.only(
                                          right:
                                              index <
                                                  pinnedParameters.length - 1
                                              ? 8
                                              : 0,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xFF61B4C6),
                                              const Color(0xFF317799),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.06,
                                              ),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              _getIndicatorLabel(param.key),
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
                                            _buildIndicatorValueCircle(
                                              _getLastValue(diary, param.key),
                                            ),
                                            const SizedBox(height: 10),
                                            Center(
                                              child: Text(
                                                _getDisplayTime(
                                                  _editedTimes[param.key] ??
                                                      param.times,
                                                ),
                                                style: GoogleFonts.firaSans(
                                                  fontSize: 11,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.grey.shade800,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 8,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  elevation: 0,
                                                ),
                                                onPressed: () =>
                                                    _selectIndicator(index),
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
                                      ),
                                    );
                                  },
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Test notification button for pinned parameters
                    // All indicators section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Все показатели',
                          style: GoogleFonts.firaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            final settings = diary?.settings;
                            final allIndicators = _normalizeIndicatorKeys(
                              settings?['all_indicators'] ??
                                  settings?['allIndicators'],
                            );

                            final pinnedKeys =
                                diary?.pinnedParameters
                                    .map((p) => p.key)
                                    .toSet() ??
                                {};

                            final availableIndicators = allIndicators
                                .where((e) => !pinnedKeys.contains(e))
                                .toList();

                            final careIndicators = availableIndicators
                                .where((e) => _careIndicatorKeys.contains(e))
                                .toList();
                            final physicalIndicators = availableIndicators
                                .where(
                                  (e) => _physicalIndicatorKeys.contains(e),
                                )
                                .toList();
                            final excretionIndicators = availableIndicators
                                .where(
                                  (e) => _excretionIndicatorKeys.contains(e),
                                )
                                .toList();
                            final symptomIndicators = availableIndicators
                                .where((e) => _symptomIndicatorKeys.contains(e))
                                .toList();
                            final customIndicators = availableIndicators
                                .where(
                                  (e) =>
                                      !_careIndicatorKeys.contains(e) &&
                                      !_physicalIndicatorKeys.contains(e) &&
                                      !_excretionIndicatorKeys.contains(e) &&
                                      !_symptomIndicatorKeys.contains(e),
                                )
                                .toList();

                            return Column(
                              children: [
                                _buildCategoryCard(
                                  categoryId: 'care',
                                  title: 'Показатели ухода',
                                  indicators: careIndicators,
                                  fallbackIndicators: _careIndicatorKeys,
                                  isExpanded: _isCareExpanded,
                                  onToggle: () =>
                                      _toggleCategoryAndShowHintIfNeeded(
                                        categoryId: 'care',
                                        isExpanded: _isCareExpanded,
                                        toggle: () =>
                                            _isCareExpanded = !_isCareExpanded,
                                      ),
                                  context: context,
                                ),
                                const SizedBox(height: 12),
                                _buildCategoryCard(
                                  categoryId: 'physical',
                                  title: 'Физические показатели',
                                  indicators: physicalIndicators,
                                  fallbackIndicators: _physicalIndicatorKeys,
                                  isExpanded: _isPhysicalExpanded,
                                  onToggle: () =>
                                      _toggleCategoryAndShowHintIfNeeded(
                                        categoryId: 'physical',
                                        isExpanded: _isPhysicalExpanded,
                                        toggle: () => _isPhysicalExpanded =
                                            !_isPhysicalExpanded,
                                      ),
                                  context: context,
                                ),
                                const SizedBox(height: 12),
                                _buildCategoryCard(
                                  categoryId: 'excretion',
                                  title: 'Выделение мочи и кала',
                                  indicators: excretionIndicators,
                                  fallbackIndicators: _excretionIndicatorKeys,
                                  isExpanded: _isExcretionExpanded,
                                  onToggle: () =>
                                      _toggleCategoryAndShowHintIfNeeded(
                                        categoryId: 'excretion',
                                        isExpanded: _isExcretionExpanded,
                                        toggle: () => _isExcretionExpanded =
                                            !_isExcretionExpanded,
                                      ),
                                  context: context,
                                ),
                                const SizedBox(height: 12),
                                _buildCategoryCard(
                                  categoryId: 'symptoms',
                                  title: 'Симптомы',
                                  indicators: symptomIndicators,
                                  fallbackIndicators: _symptomIndicatorKeys,
                                  isExpanded: _isSymptomsExpanded,
                                  onToggle: () =>
                                      _toggleCategoryAndShowHintIfNeeded(
                                        categoryId: 'symptoms',
                                        isExpanded: _isSymptomsExpanded,
                                        toggle: () => _isSymptomsExpanded =
                                            !_isSymptomsExpanded,
                                      ),
                                  context: context,
                                ),
                                if (customIndicators.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _buildCategoryCard(
                                    categoryId: 'custom',
                                    title: 'Дополнительные показатели',
                                    indicators: customIndicators,
                                    fallbackIndicators: const [],
                                    isExpanded: _isCustomIndicatorsExpanded,
                                    onToggle: () =>
                                        _toggleCategoryAndShowHintIfNeeded(
                                          categoryId: 'custom',
                                          isExpanded:
                                              _isCustomIndicatorsExpanded,
                                          toggle: () =>
                                              _isCustomIndicatorsExpanded =
                                                  !_isCustomIndicatorsExpanded,
                                        ),
                                    context: context,
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Кнопки "Изменить показатели" и "Управление доступом" скрыты для сиделок
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, authState) {
                        // Скрываем кнопки для сиделок (caregiver) и врачей/сиделок от организации
                        if (authState is AuthAuthenticated) {
                          final type = authState.user.accountType;
                          // Скрываем для doctor и caregiver (сотрудники организации)
                          if (type == 'doctor' || type == 'caregiver') {
                            return const SizedBox.shrink();
                          }
                          // Скрываем для клиентов с ролью caregiver
                          if (type == 'client' &&
                              authState.user.hasRole('caregiver')) {
                            return const SizedBox.shrink();
                          }
                        }

                        return Container(
                          child: Column(
                            children: [
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () async {
                                    log.debug(
                                      'Diary selected',
                                      context: LogContext.diary,
                                      extra: {'diary': diary?.toJson()},
                                    );
                                    if (diary != null) {
                                      // Получаем all_indicators из settings
                                      final allIndicators =
                                          (diary.settings?['all_indicators']
                                                  as List<dynamic>?)
                                              ?.map((e) => e.toString())
                                              .toList() ??
                                          [];
                                      final result = await context.push(
                                        '/select-entry-to-edit',
                                        extra: {
                                          'diaryId': widget.diaryId,
                                          'patientId': widget.patientId,
                                          'entries': diary.entries,
                                          'pinnedParameters':
                                              diary.pinnedParameters,
                                          'allIndicators': allIndicators,
                                        },
                                      );
                                      // Перезагружаем дневник если были изменения
                                      if (result == true && mounted) {
                                        context.read<DiaryBloc>().add(
                                          LoadDiary(widget.diaryId),
                                        );
                                      }
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Нет записей для редактирования',
                                            style: GoogleFonts.firaSans(),
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    'Изменить показатели',
                                    style: GoogleFonts.firaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppConfig.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Access management section - скрыт для врачей
                              if (!(authState is AuthAuthenticated &&
                                  authState.user.accountType == 'client' &&
                                  authState.user.hasRole('doctor')))
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          final wasExpanded =
                                              _isAccessManagementExpanded;
                                          setState(() {
                                            _isAccessManagementExpanded =
                                                !_isAccessManagementExpanded;
                                          });
                                          // Загружаем данные при первом раскрытии
                                          if (!wasExpanded &&
                                              _diaryAccessList.isEmpty &&
                                              _allEmployees.isEmpty) {
                                            _loadDiaryAccess();
                                          }
                                        },
                                        borderRadius: BorderRadius.vertical(
                                          top: const Radius.circular(12),
                                          bottom: Radius.circular(
                                            _isAccessManagementExpanded
                                                ? 0
                                                : 12,
                                          ),
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 6,
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                'Управление доступом',
                                                style: GoogleFonts.firaSans(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.red.shade600,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 3),
                                              Center(
                                                child: Transform.rotate(
                                                  angle:
                                                      _isAccessManagementExpanded
                                                      ? 4.71239
                                                      : 1.5708,
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
                                      if (_isAccessManagementExpanded)
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  bottom: Radius.circular(12),
                                                ),
                                            border: Border(
                                              top: BorderSide(
                                                color: Colors.grey.shade300,
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    'Доступ к дневнику',
                                                    style: GoogleFonts.firaSans(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          Colors.grey.shade900,
                                                    ),
                                                  ),
                                                  TextButton.icon(
                                                    onPressed:
                                                        _showAddAccessDialog,
                                                    icon: Icon(
                                                      Icons.add,
                                                      size: 18,
                                                      color: AppConfig
                                                          .primaryColor,
                                                    ),
                                                    label: Text(
                                                      'Добавить',
                                                      style:
                                                          GoogleFonts.firaSans(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: AppConfig
                                                                .primaryColor,
                                                          ),
                                                    ),
                                                    style: TextButton.styleFrom(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              if (_isLoadingAccess)
                                                const Center(
                                                  child: Padding(
                                                    padding: EdgeInsets.all(20),
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                                )
                                              else if (_diaryAccessList.isEmpty)
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    'Нет индивидуальных доступов.\nВсе сотрудники организации имеют доступ автоматически.',
                                                    style: GoogleFonts.firaSans(
                                                      fontSize: 13,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                )
                                              else
                                                ...(_diaryAccessList.map((
                                                  access,
                                                ) {
                                                  // Новый формат API: id, first_name, last_name, phone, permission, status, granted_at
                                                  final odUserId =
                                                      access['id'] as int?;
                                                  final firstName =
                                                      access['first_name']
                                                          as String? ??
                                                      '';
                                                  final lastName =
                                                      access['last_name']
                                                          as String? ??
                                                      '';
                                                  final phone =
                                                      access['phone']
                                                          as String?;
                                                  final permission =
                                                      access['permission']
                                                          as String? ??
                                                      'edit';

                                                  String userName =
                                                      '$lastName $firstName'
                                                          .trim();
                                                  if (userName.isEmpty) {
                                                    userName =
                                                        phone ??
                                                        'Пользователь #$odUserId';
                                                  }

                                                  return Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          bottom: 8,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.all(
                                                          12,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors
                                                            .grey
                                                            .shade200,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        CircleAvatar(
                                                          radius: 18,
                                                          backgroundColor:
                                                              AppConfig
                                                                  .primaryColor
                                                                  .withOpacity(
                                                                    0.1,
                                                                  ),
                                                          child: Text(
                                                            userName.isNotEmpty
                                                                ? userName[0]
                                                                      .toUpperCase()
                                                                : '?',
                                                            style: TextStyle(
                                                              color: AppConfig
                                                                  .primaryColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 12,
                                                        ),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                userName,
                                                                style: GoogleFonts.firaSans(
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  color: Colors
                                                                      .grey
                                                                      .shade900,
                                                                ),
                                                              ),
                                                              if (phone !=
                                                                      null &&
                                                                  phone
                                                                      .isNotEmpty)
                                                                Text(
                                                                  phone,
                                                                  style: GoogleFonts.firaSans(
                                                                    fontSize:
                                                                        12,
                                                                    color: Colors
                                                                        .grey
                                                                        .shade600,
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 4,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                permission ==
                                                                        'edit' ||
                                                                    permission ==
                                                                        'full'
                                                                ? Colors
                                                                      .green
                                                                      .shade50
                                                                : Colors
                                                                      .blue
                                                                      .shade50,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  4,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            permission == 'full'
                                                                ? 'Полный'
                                                                : permission ==
                                                                      'edit'
                                                                ? 'Редактирование'
                                                                : 'Просмотр',
                                                            style: GoogleFonts.firaSans(
                                                              fontSize: 11,
                                                              color:
                                                                  permission ==
                                                                          'edit' ||
                                                                      permission ==
                                                                          'full'
                                                                  ? Colors
                                                                        .green
                                                                        .shade700
                                                                  : Colors
                                                                        .blue
                                                                        .shade700,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        IconButton(
                                                          icon: Icon(
                                                            Icons
                                                                .delete_outline,
                                                            color: Colors
                                                                .red
                                                                .shade400,
                                                            size: 20,
                                                          ),
                                                          onPressed: () {
                                                            if (odUserId !=
                                                                null) {
                                                              showDialog(
                                                                context:
                                                                    context,
                                                                builder: (ctx) => AlertDialog(
                                                                  title: Text(
                                                                    'Отозвать доступ?',
                                                                    style: GoogleFonts.firaSans(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                    ),
                                                                  ),
                                                                  content: Text(
                                                                    'Вы уверены, что хотите отозвать доступ у $userName?',
                                                                    style:
                                                                        GoogleFonts.firaSans(),
                                                                  ),
                                                                  actions: [
                                                                    TextButton(
                                                                      onPressed: () =>
                                                                          Navigator.pop(
                                                                            ctx,
                                                                          ),
                                                                      child: Text(
                                                                        'Отмена',
                                                                        style: GoogleFonts.firaSans(
                                                                          color: Colors
                                                                              .grey
                                                                              .shade600,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    TextButton(
                                                                      onPressed: () {
                                                                        Navigator.pop(
                                                                          ctx,
                                                                        );
                                                                        _revokeDiaryAccess(
                                                                          odUserId,
                                                                          userName,
                                                                        );
                                                                      },
                                                                      child: Text(
                                                                        'Отозвать',
                                                                        style: GoogleFonts.firaSans(
                                                                          color:
                                                                              Colors.red,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              );
                                                            }
                                                          },
                                                          padding:
                                                              EdgeInsets.zero,
                                                          constraints:
                                                              const BoxConstraints(),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }).toList()),
                                              const SizedBox(height: 12),
                                              TextButton(
                                                onPressed: _loadDiaryAccess,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.refresh,
                                                      size: 16,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Обновить список',
                                                      style:
                                                          GoogleFonts.firaSans(
                                                            fontSize: 13,
                                                            color: Colors
                                                                .grey
                                                                .shade600,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Получить человекочитаемое название показателя по ключу API
  /// Делегирует вызов в утилиты для централизованного управления
  String _getIndicatorLabel(String key) => diary_utils.getIndicatorLabel(key);

  /// Показать модальное окно для заполнения параметра
  void _showIndicatorModal(
    BuildContext context,
    String key,
    String label, {
    bool showAllIndicatorsCareSaveHint = false,
  }) {
    // Определяем тип модального окна по ключу параметра
    final booleanParams = [
      'skin_moisturizing',
      'hygiene',
      'defecation',
      'nausea',
      'vomiting',
      'dyspnea',
      'itching',
      'cough',
      'dry_mouth',
      'hiccup',
      'taste_disorder',
      'walk', // Прогулка - было/не было
    ];

    final textParams = ['feeding', 'cognitive_games', 'meal'];
    final timeRangeParams = ['sleep'];
    final timeParams = ['diaper_change'];
    final measurementParams = [
      'blood_pressure',
      'temperature',
      'pulse',
      'saturation',
      'respiratory_rate',
      'pain_level',
      'sugar_level',
      'fluid_intake',
      'urine_output',
    ];

    if (booleanParams.contains(key)) {
      _showBooleanModal(
        context,
        label,
        _getIndicatorDescription(key),
        key,
        showTutorialHint: showAllIndicatorsCareSaveHint,
      );
    } else if (textParams.contains(key)) {
      _showTextModal(
        context,
        label,
        _getIndicatorDescription(key),
        _getIndicatorHint(key),
        key,
        showTutorialHint: showAllIndicatorsCareSaveHint,
      );
    } else if (timeRangeParams.contains(key)) {
      _showTimeRangeModal(
        context,
        label,
        _getIndicatorDescription(key),
        key,
        showTutorialHint: showAllIndicatorsCareSaveHint,
      );
    } else if (timeParams.contains(key)) {
      _showTimeModal(context, label, _getIndicatorDescription(key), key);
    } else if (measurementParams.contains(key)) {
      _showMeasurementModal(
        context,
        label,
        _getIndicatorDescription(key),
        _getUnitForParameter(key),
        key,
        showTutorialHint: showAllIndicatorsCareSaveHint,
      );
    } else if (key == 'medication' || key == 'vitamins') {
      _showMedicationModal(
        context,
        label,
        _getIndicatorDescription(key),
        key,
        showTutorialHint: showAllIndicatorsCareSaveHint,
      );
    } else if (key == 'urine_color') {
      _showUrineColorModal(context, label);
    } else {
      _showMeasurementModal(
        context,
        label,
        _getIndicatorDescription(key),
        _getIndicatorHint(key),
        key,
        showTutorialHint: showAllIndicatorsCareSaveHint,
      );
    }
  }

  /// Получить описание показателя для модального окна
  /// Делегирует вызов в утилиты для централизованного управления
  String _getIndicatorDescription(String key) =>
      diary_utils.getIndicatorDescription(key);

  /// Получить подсказку для текстового ввода
  /// Делегирует вызов в утилиты для централизованного управления
  String _getIndicatorHint(String key) => diary_utils.getIndicatorHint(key);

  /// Модальное окно с выбором Было/Не было
  /// Использует готовый компонент из modals и добавляет бизнес-логику сохранения
  void _showBooleanModal(
    BuildContext context,
    String title,
    String description,
    String key, {
    bool showTutorialHint = false,
  }) async {
    final selectedValue = await modals.showBooleanModal(
      context: context,
      title: title,
      description: description,
    );

    if (selectedValue != null && mounted) {
      log.d('--- Save Boolean ---');
      log.d('Key: $key, Value: $selectedValue');

      context.read<DiaryBloc>().add(
        CreateMeasurement(
          patientId: widget.patientId,
          type: _getParameterType(key),
          key: key,
          value: {'value': selectedValue},
          recordedAt: DateTime.now(),
        ),
      );

      if (showTutorialHint) {
        _showAllIndicatorsSavedHint();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title: ${selectedValue ? "Было" : "Не было"}'),
            backgroundColor: AppConfig.primaryColor,
          ),
        );
      }
    }
  }

  /// Модальное окно с текстовым вводом
  /// Использует готовый компонент из modals
  void _showTextModal(
    BuildContext context,
    String title,
    String description,
    String hint,
    String key, {
    bool showTutorialHint = false,
  }) async {
    final result = await modals.showTextInputModal(
      context: context,
      title: title,
      description: description,
      hint: hint,
    );

    if (result != null && result.isNotEmpty && mounted) {
      context.read<DiaryBloc>().add(
        CreateMeasurement(
          patientId: widget.patientId,
          type: _getParameterType(key),
          key: key,
          value: {'value': result},
          recordedAt: DateTime.now(),
        ),
      );

      if (showTutorialHint) {
        _showAllIndicatorsSavedHint();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title сохранено'),
            backgroundColor: AppConfig.primaryColor,
          ),
        );
      }
    }
  }

  /// Модальное окно с выбором времени
  Future<void> _showTimeModal(
    BuildContext context,
    String title,
    String description,
    String key,
  ) async {
    final selectedTime = await showTimePickerModal(
      context: context,
      title: title,
      description: description,
      initialTime: TimeOfDay.now(),
    );

    if (selectedTime != null) {
      // Сохраняем запись в дневник
      if (context.mounted) {
        context.read<DiaryBloc>().add(
          CreateMeasurement(
            patientId: widget.patientId,
            key: key,
            value: {'value': selectedTime.format(context)},
            recordedAt: DateTime.now(),
            type: _getParameterType(key),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title: ${selectedTime.format(context)}'),
            backgroundColor: AppConfig.primaryColor,
          ),
        );
      }
    }
  }

  /// Модальное окно с диапазоном времени
  /// Использует готовый компонент из modals и добавляет бизнес-логику сохранения
  void _showTimeRangeModal(
    BuildContext context,
    String title,
    String description,
    String key, {
    bool showTutorialHint = false,
  }) async {
    final result = await modals.showTimeRangeModal(
      context: context,
      title: title,
      description: description,
    );

    if (result != null && mounted) {
      // Сохраняем запись в дневник
      context.read<DiaryBloc>().add(
        CreateMeasurement(
          patientId: widget.patientId,
          key: key,
          value: {
            'start': result.startTime.format(context),
            'end': result.endTime.format(context),
          },
          recordedAt: DateTime.now(),
          type: _getParameterType(key),
        ),
      );

      if (showTutorialHint) {
        _showAllIndicatorsSavedHint();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title: ${result.formattedRange}'),
            backgroundColor: AppConfig.primaryColor,
          ),
        );
      }
    }
  }

  /// Модальное окно с вводом измерения
  /// Использует готовый компонент из modals и добавляет бизнес-логику сохранения
  void _showMeasurementModal(
    BuildContext context,
    String title,
    String description,
    String unit,
    String key, {
    bool showTutorialHint = false,
  }) async {
    final result = await modals.showMeasurementModal(
      context: context,
      title: title,
      description: description,
      unit: unit,
      key: key,
    );

    if (result != null && mounted) {
      log.d('--- Save Measurement ---');
      log.d('Key: $key, Value: ${result.value}');

      context.read<DiaryBloc>().add(
        CreateMeasurement(
          patientId: widget.patientId,
          type: _getParameterType(key),
          key: key,
          value: {'value': result.value},
          recordedAt: DateTime.now(),
        ),
      );

      if (showTutorialHint) {
        _showAllIndicatorsSavedHint();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title: ${result.displayText}'),
            backgroundColor: AppConfig.primaryColor,
          ),
        );
      }
    }
  }

  /// Модальное окно для лекарств/витаминов
  /// Использует готовый компонент из modals и добавляет бизнес-логику сохранения
  void _showMedicationModal(
    BuildContext context,
    String title,
    String description,
    String key, {
    bool showTutorialHint = false,
  }) async {
    final result = await modals.showTextInputModal(
      context: context,
      title: title,
      description: description,
      hint: 'Введите название',
    );

    if (result != null && result.isNotEmpty && mounted) {
      log.debug(
        'Save Medication/Vitamins',
        context: LogContext.diary,
        extra: {'key': key, 'value': result},
      );

      context.read<DiaryBloc>().add(
        CreateMeasurement(
          patientId: widget.patientId,
          type: _getParameterType(key),
          key: key,
          value: {'value': result},
          recordedAt: DateTime.now(),
        ),
      );

      if (showTutorialHint) {
        _showAllIndicatorsSavedHint();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title: $result'),
            backgroundColor: AppConfig.primaryColor,
          ),
        );
      }
    }
  }

  /// Модальное окно для выбора цвета мочи
  /// Использует готовый компонент из modals и добавляет бизнес-логику сохранения
  void _showUrineColorModal(BuildContext context, String title) async {
    final selectedColor = await modals.showUrineColorModal(
      context: context,
      title: title,
    );

    if (selectedColor != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title: $selectedColor'),
          backgroundColor: AppConfig.primaryColor,
        ),
      );
    }
  }

  Widget _buildExpandedIndicatorCard(
    BuildContext blocContext,
    int index,
    List<PinnedParameter> pinnedParameters,
    Diary? diary,
  ) {
    final param = pinnedParameters[index];
    final indicatorName = _getIndicatorLabel(param.key);
    final measurementController =
        _measurementControllers[index] ?? TextEditingController();
    final timeController = _timeControllers[index] ?? TextEditingController();
    final times = _editedTimes[param.key] ?? param.times;

    if (!_measurementControllers.containsKey(index)) {
      _measurementControllers[index] = measurementController;
      _timeControllers[index] = timeController;
      _fillCounts[index] = 0;
    }

    final timeFormatter = MaskTextInputFormatter(
      mask: '##:##',
      filter: {'#': RegExp(r'[0-9]')},
    );

    return Container(
      key: ValueKey('expanded_indicator_$index'),
      height: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF61B4C6), const Color(0xFF317799)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left section: Title, circle, time text, save button
          Expanded(
            flex: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  indicatorName,
                  style: GoogleFonts.firaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                _buildIndicatorValueCircle(_getLastValue(diary, param.key)),
                const SizedBox(height: 10),
                // Время заполнения
                Center(
                  child: Text(
                    _getDisplayTime(_editedTimes[param.key] ?? param.times),
                    style: GoogleFonts.firaSans(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black45,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      // Если в поле ввода времени есть значение, добавляем его в список
                      if (timeController.text.length == 5) {
                        final currentTimes =
                            _editedTimes[param.key] ?? param.times;
                        if (!currentTimes.contains(timeController.text)) {
                          final newTimes = List<String>.from(currentTimes);
                          newTimes.add(timeController.text);
                          newTimes.sort();
                          _editedTimes[param.key] = newTimes;
                        }
                      }

                      bool hasChanges = false;
                      // 1. Save Settings (Times)
                      if (_editedTimes.containsKey(param.key)) {
                        final updatedParams = pinnedParameters.map((p) {
                          if (_editedTimes.containsKey(p.key)) {
                            return PinnedParameter(
                              key: p.key,
                              intervalMinutes: p.intervalMinutes < 1
                                  ? 60
                                  : p.intervalMinutes,
                              times: _editedTimes[p.key]!,
                              settings: p.settings,
                              lastRecordedAt: p.lastRecordedAt,
                            );
                          }
                          return p;
                        }).toList();

                        blocContext.read<DiaryBloc>().add(
                          SavePinnedParameters(
                            patientId: widget.patientId,
                            pinnedParameters: updatedParams,
                          ),
                        );
                        hasChanges = true;
                      }

                      final hasMeasurementInput = param.key == 'blood_pressure'
                          ? (measurementController.text.isNotEmpty &&
                                (_diastolicControllers[index]
                                        ?.text
                                        .isNotEmpty ??
                                    false))
                          : measurementController.text.isNotEmpty;

                      if (hasMeasurementInput) {
                        dynamic value;

                        if (param.key == 'blood_pressure') {
                          final systolic = measurementController.text.trim();
                          final diastolic =
                              _diastolicControllers[index]?.text.trim() ?? '';
                          value = {
                            'systolic': int.tryParse(systolic) ?? 0,
                            'diastolic': int.tryParse(diastolic) ?? 0,
                          };
                        } else if (_booleanParams.contains(param.key)) {
                          value = measurementController.text == 'true';
                        } else if (_measurementParams.contains(param.key)) {
                          final numValue = num.tryParse(
                            measurementController.text.toString().replaceAll(
                              ',',
                              '.',
                            ),
                          );
                          value = numValue ?? measurementController.text;
                        } else if (_textParams.contains(param.key)) {
                          value = {'value': measurementController.text};
                        } else {
                          value = measurementController.text;
                        }

                        log.d('--- Create Measurement Log ---');
                        log.d('Key: ${param.key}');
                        log.d('Raw Input: ${measurementController.text}');
                        log.d('Processed Value: $value');
                        log.d('------------------------------');

                        blocContext.read<DiaryBloc>().add(
                          CreateMeasurement(
                            patientId: widget.patientId,
                            type: _getParameterType(param.key),
                            key: param.key,
                            value: {'value': value},
                            notes: null,
                            recordedAt: DateTime.now(),
                          ),
                        );
                        measurementController.clear();
                        if (param.key == 'blood_pressure') {
                          _diastolicControllers[index]?.clear();
                        }
                        hasChanges = true;
                      }

                      if (hasChanges) {
                        _pendingHintAfterCloseId =
                            HintIds.healthDiaryAllIndicators;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Данные сохранены')),
                        );
                      }

                      _closeIndicator();
                    },
                    child: Text(
                      'Сохранить',
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
          ),
          const SizedBox(width: 12),
          // Right section: Input fields
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Measurement Input - динамический в зависимости от типа параметра
                  _buildParameterInputWidget(
                    param: param,
                    measurementController: measurementController,
                    blocContext: blocContext,
                    index: index,
                  ),
                  const SizedBox(height: 10), // Уменьшен отступ
                  // Times Logic
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF7DCAD6),
                          const Color(0xFF55ACBF),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final TimeOfDay? pickedTime =
                                await showTimePickerModal(
                                  context: context,
                                  title: 'Выберите время',
                                  description: 'Время заполнения',
                                  initialTime: TimeOfDay.now(),
                                );
                            if (pickedTime != null) {
                              final timeString =
                                  '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
                              setState(() {
                                final newTimes = List<String>.from(times);
                                if (!newTimes.contains(timeString)) {
                                  newTimes.add(timeString);
                                  newTimes.sort();
                                  _editedTimes[param.key] = newTimes;
                                }
                              });
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Время заполнения:',
                                style: GoogleFonts.firaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${times.length} раз(а)',
                                style: GoogleFonts.firaSans(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (times.isNotEmpty)
                          SizedBox(
                            height: 24,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: times.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 4),
                              itemBuilder: (context, i) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      times[i],
                                      style: GoogleFonts.firaSans(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          final newTimes = List<String>.from(
                                            times,
                                          );
                                          newTimes.removeAt(i);
                                          _editedTimes[param.key] = newTimes;
                                        });
                                      },
                                      child: const Icon(
                                        Icons.close,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (times.isNotEmpty) const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: SizedBox(
                                height: 38,
                                child: TextFormField(
                                  controller: timeController,
                                  inputFormatters: [timeFormatter],
                                  style: GoogleFonts.firaSans(
                                    fontSize: 14,
                                    color: Colors.grey.shade900,
                                    height: 1.2,
                                  ),
                                  textAlignVertical: TextAlignVertical.center,
                                  decoration: InputDecoration(
                                    hintText: '-:-',
                                    hintStyle: GoogleFonts.firaSans(
                                      fontSize: 14,
                                      color: Colors.grey.shade400,
                                      height: 1.2,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    suffixIcon: const Icon(
                                      Icons.access_time,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  keyboardType: TextInputType.text,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                if (timeController.text.length == 5) {
                                  setState(() {
                                    final newTimes = List<String>.from(times);
                                    if (!newTimes.contains(
                                      timeController.text,
                                    )) {
                                      newTimes.add(timeController.text);
                                      newTimes.sort();
                                      _editedTimes[param.key] = newTimes;
                                    }
                                  });
                                  timeController.clear();
                                }
                              },
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF317799),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineCalendar(
    DateTime initialDate,
    Function(DateTime) onDateSelected,
  ) {
    return StatefulBuilder(
      builder: (context, setState) {
        DateTime selectedDate = initialDate;
        DateTime currentMonth = DateTime(initialDate.year, initialDate.month);

        return Container(
          padding: const EdgeInsets.all(20),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with month navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        currentMonth = DateTime(
                          currentMonth.year,
                          currentMonth.month - 1,
                        );
                      });
                    },
                  ),
                  Text(
                    DateFormat('MMMM y', 'ru').format(currentMonth),
                    style: GoogleFonts.firaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() {
                        currentMonth = DateTime(
                          currentMonth.year,
                          currentMonth.month + 1,
                        );
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Calendar
              _buildCalendarGrid(currentMonth, selectedDate, (date) {
                setState(() {
                  selectedDate = date;
                });
                onDateSelected(date);
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalendarGrid(
    DateTime month,
    DateTime selectedDate,
    Function(DateTime) onDateTap,
  ) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final firstDayWeekday = firstDay.weekday == 7 ? 0 : firstDay.weekday;
    final daysInMonth = lastDay.day;
    final daysInPrevMonth = DateTime(month.year, month.month, 0).day;

    final List<Widget> dayWidgets = [];
    final weekDays = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

    // Week day headers
    for (var day in weekDays) {
      dayWidgets.add(
        Container(
          height: 40,
          alignment: Alignment.center,
          child: Text(
            day,
            style: GoogleFonts.firaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    // Previous month days
    for (int i = firstDayWeekday - 1; i >= 0; i--) {
      final day = daysInPrevMonth - i;
      dayWidgets.add(
        Container(
          height: 40,
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: GoogleFonts.firaSans(
              fontSize: 14,
              color: Colors.grey.shade300,
            ),
          ),
        ),
      );
    }

    // Current month days
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final isSelected =
          date.year == selectedDate.year &&
          date.month == selectedDate.month &&
          date.day == selectedDate.day;
      final isToday =
          date.year == DateTime.now().year &&
          date.month == DateTime.now().month &&
          date.day == DateTime.now().day;

      dayWidgets.add(
        GestureDetector(
          onTap: () => onDateTap(date),
          child: Container(
            height: 40,
            width: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppConfig.primaryColor.withOpacity(0.2)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppConfig.primaryColor : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$day',
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: isSelected
                      ? Colors.white
                      : isToday
                      ? AppConfig.primaryColor
                      : Colors.grey.shade900,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Next month days
    final remainingDays = 42 - dayWidgets.length;
    for (int day = 1; day <= remainingDays; day++) {
      dayWidgets.add(
        Container(
          height: 40,
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: GoogleFonts.firaSans(
              fontSize: 14,
              color: Colors.grey.shade300,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: dayWidgets.length,
      itemBuilder: (context, index) => dayWidgets[index],
    );
  }

  Widget _buildHistoryTab(BuildContext context, Diary? diary) {
    if (diary == null) return const SizedBox();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          context.read<DiaryBloc>().add(LoadDiary(widget.diaryId));
          // Ждём пока состояние изменится
          await Future.delayed(const Duration(milliseconds: 500));
        },
        color: AppConfig.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'НАЖМИТЕ, ЧТОБЫ ВЫБРАТЬ ДАТУ ИСТОРИИ ЗАПОЛНЕНИЯ',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.firaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        // Форматируем дату с заглавной первой буквой
                        final formattedDate = DateFormat(
                          "EEEE, d MMMM y'г'",
                          'ru',
                        ).format(_selectedDate);
                        final capitalizedDate =
                            formattedDate[0].toUpperCase() +
                            formattedDate.substring(1);

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _isHistoryDatePickerExpanded =
                                  !_isHistoryDatePickerExpanded;
                            });
                          },
                          borderRadius: BorderRadius.circular(28),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 20,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFE5F4F7), Color(0xFFD0EDF2)],
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF2B8A9E,
                                  ).withOpacity(0.12),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Дата
                                Text(
                                  capitalizedDate,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.firaSans(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1A6B7C),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Подсказка
                                Text(
                                  'Отчёт будет построен за этот день',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.firaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xFF6BC4D4),
                                  ),
                                ),
                                if (_isHistoryDatePickerExpanded) ...[
                                  const SizedBox(height: 16),
                                  // Полноценный календарь
                                  _buildHistoryCalendarGrid(),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Контейнер для двух блоков
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4F6),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Принятые лекарства и витамины',
                      style: GoogleFonts.firaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_getMedicationEntries(diary).isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Center(
                          child: Text(
                            'Нет записей за эту дату',
                            style: GoogleFonts.firaSans(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Заголовок категории
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 8),
                            child: Text(
                              'ПРИЕМ ЛЕКАРСТВ',
                              style: GoogleFonts.firaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                          // Записи
                          ..._getMedicationEntries(diary).map((entry) {
                            // Используем централизованный метод форматирования
                            final displayValue = _formatEntryValue(entry);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFF8CD4E0),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      displayValue,
                                      style: GoogleFonts.firaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    DateFormat(
                                      'HH:mm',
                                    ).format(entry.recordedAt.toLocal()),
                                    style: GoogleFonts.firaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF5BBCC9),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    const SizedBox(height: 24),
                    _buildHistoryEntriesList(_getOtherEntries(diary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCalendarGrid() {
    // Получаем первый день месяца
    final firstDayOfMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      1,
    );
    // День недели первого дня (1 = понедельник, 7 = воскресенье)
    int firstWeekday = firstDayOfMonth.weekday;
    // Количество дней в месяце
    final daysInMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
    ).day;
    // Количество дней в предыдущем месяце
    final daysInPrevMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      0,
    ).day;

    // Названия дней недели
    const weekDays = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

    // Форматируем название месяца
    final monthName = DateFormat('LLLL yyyy', 'ru').format(_selectedDate);
    final capitalizedMonth =
        monthName[0].toUpperCase() + monthName.substring(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Заголовок с навигацией
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Кнопка назад
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = DateTime(
                      _selectedDate.year,
                      _selectedDate.month - 1,
                      1,
                    );
                  });
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.chevron_left,
                    color: Color(0xFF5BBCC9),
                    size: 20,
                  ),
                ),
              ),
              // Название месяца
              Text(
                capitalizedMonth,
                style: GoogleFonts.firaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A6B7C),
                ),
              ),
              // Кнопка вперед
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = DateTime(
                      _selectedDate.year,
                      _selectedDate.month + 1,
                      1,
                    );
                  });
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF5BBCC9),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Дни недели
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDays.map((day) {
              return SizedBox(
                width: 36,
                child: Center(
                  child: Text(
                    day,
                    style: GoogleFonts.firaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A6B7C),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Сетка дней
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: 42, // 6 недель * 7 дней
            itemBuilder: (context, index) {
              int dayNumber;
              bool isCurrentMonth = true;
              bool isNextMonth = false;

              if (index < firstWeekday - 1) {
                // Дни предыдущего месяца
                dayNumber = daysInPrevMonth - (firstWeekday - 2 - index);
                isCurrentMonth = false;
              } else if (index >= firstWeekday - 1 + daysInMonth) {
                // Дни следующего месяца
                dayNumber = index - (firstWeekday - 1) - daysInMonth + 1;
                isCurrentMonth = false;
                isNextMonth = true;
              } else {
                // Дни текущего месяца
                dayNumber = index - (firstWeekday - 1) + 1;
              }

              final isSelected =
                  isCurrentMonth && dayNumber == _selectedDate.day;

              return GestureDetector(
                onTap: () {
                  if (isCurrentMonth) {
                    setState(() {
                      _selectedDate = DateTime(
                        _selectedDate.year,
                        _selectedDate.month,
                        dayNumber,
                      );
                      _isHistoryDatePickerExpanded = false;
                    });
                  } else if (!isNextMonth) {
                    // Предыдущий месяц
                    setState(() {
                      final prevMonth = DateTime(
                        _selectedDate.year,
                        _selectedDate.month - 1,
                        dayNumber,
                      );
                      _selectedDate = prevMonth;
                      _isHistoryDatePickerExpanded = false;
                    });
                  } else {
                    // Следующий месяц
                    setState(() {
                      final nextMonth = DateTime(
                        _selectedDate.year,
                        _selectedDate.month + 1,
                        dayNumber,
                      );
                      _selectedDate = nextMonth;
                      _isHistoryDatePickerExpanded = false;
                    });
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF5BBCC9)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$dayNumber',
                      style: GoogleFonts.firaSans(
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : isCurrentMonth
                            ? const Color(0xFF1A6B7C)
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<DiaryEntry> _getMedicationEntries(Diary diary) {
    return _getFormattedEntries(diary).where((entry) {
      return entry.parameterKey == 'medication' ||
          entry.parameterKey == 'vitamins';
    }).toList();
  }

  List<DiaryEntry> _getOtherEntries(Diary diary) {
    return _getFormattedEntries(diary);
  }

  List<DiaryEntry> _getFormattedEntries(Diary diary) {
    final filtered = diary.entries.where((entry) {
      final localRecordedAt = entry.recordedAt.toLocal();
      final matches =
          localRecordedAt.year == _selectedDate.year &&
          localRecordedAt.month == _selectedDate.month &&
          localRecordedAt.day == _selectedDate.day;
      return matches;
    }).toList()..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    return filtered;
  }

  Widget _buildHistoryEntriesList(List<DiaryEntry> entries) {
    if (entries.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Отчёт за сегодня',
            style: GoogleFonts.firaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Center(
              child: Text(
                'Нет записей за эту дату',
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Группируем записи по названию показателя (ключу параметра)
    final Map<String, List<DiaryEntry>> groupedEntries = {};
    for (final entry in entries) {
      final parameterKey = entry.parameterKey;
      if (!groupedEntries.containsKey(parameterKey)) {
        groupedEntries[parameterKey] = [];
      }
      groupedEntries[parameterKey]!.add(entry);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Отчёт за сегодня',
          style: GoogleFonts.firaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 12),
        ...groupedEntries.entries.map((group) {
          // Получаем человекочитаемое название показателя
          final indicatorLabel = _getIndicatorLabel(group.key);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок - название показателя
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Text(
                  indicatorLabel.toUpperCase(),
                  style: GoogleFonts.firaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              // Записи показателя
              ...group.value.map((entry) {
                // Форматируем значение для отображения
                String displayValue = _formatEntryValue(entry);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF8CD4E0),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          displayValue,
                          style: GoogleFonts.firaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('HH:mm').format(entry.recordedAt.toLocal()),
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF5BBCC9),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          );
        }),
      ],
    );
  }

  /// Форматирует значение записи для отображения в истории
  String _formatEntryValue(DiaryEntry entry) {
    // entry.value теперь Map<String,dynamic> — используем dynamic для совместимости
    dynamic value = entry.value;

    // Показатели времени не должны преобразовываться в "Было"/"Не было"
    const timeParams = [
      'diaper_change',
      'bath',
      'nail_care',
      'hair_care',
      'shaving',
    ];

    // Обработка булевых значений (кроме показателей времени)
    if (value is bool && !timeParams.contains(entry.parameterKey)) {
      return value ? 'Было' : 'Не было';
    }

    // Обработка числовых булевых представлений (1/0) - кроме показателей времени
    if (value is num && !timeParams.contains(entry.parameterKey)) {
      if (value == 1) return 'Было';
      if (value == 0) return 'Не было';
    }

    // ... (код для blood_pressure пропускаем, он выше затронут через search/replace сложнее будет попасть, лучше точечно)
    // ... вернемся к Value processing после blood_pressure

    // Рекурсивное извлечение вложенного значения из цепочки {value: {value: {value: ...}}}
    while (value is Map && value.containsKey('value')) {
      value = value['value'];
    }

    // После извлечения проверяем финальный тип (кроме показателей времени)
    if (value is bool && !timeParams.contains(entry.parameterKey)) {
      return value ? 'Было' : 'Не было';
    }

    if (value is num && !timeParams.contains(entry.parameterKey)) {
      if (value == 1) return 'Было';
      if (value == 0) return 'Не было';
      final displayValue = value.toString();
      final unit = _getUnitForParameter(entry.parameterKey);
      // Проверяем, не содержит ли значение уже единицу измерения
      if (unit.isNotEmpty && !displayValue.contains(unit)) {
        return '$displayValue $unit';
      }
      return displayValue;
    }

    if (value is String) {
      // Для временных параметров добавляем "Было в"
      if (timeParams.contains(entry.parameterKey)) {
        // Проверяем, является ли значение временем в формате HH:mm
        if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(value)) {
          return 'Было в $value';
        }
      }

      final displayValue = value;
      final unit = _getUnitForParameter(entry.parameterKey);

      // Проверяем, не содержит ли значение уже единицу измерения
      if (unit.isNotEmpty && !displayValue.contains(unit)) {
        return '$displayValue $unit';
      }
      return displayValue;
    }

    // Для Map с одним значением - извлекаем его
    if (value is Map && value.length == 1) {
      final singleValue = value.values.first;
      if (singleValue is bool && !timeParams.contains(entry.parameterKey)) {
        return singleValue ? 'Было' : 'Не было';
      }
      if (singleValue is String || singleValue is num) {
        final displayValue = singleValue.toString();

        // Для временных параметров добавляем "Было в"
        if (timeParams.contains(entry.parameterKey) && singleValue is String) {
          if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(displayValue)) {
            return 'Было в $displayValue';
          }
        }

        final unit = _getUnitForParameter(entry.parameterKey);
        // Проверяем, не содержит ли значение уже единицу измерения
        if (unit.isNotEmpty && !displayValue.contains(unit)) {
          return '$displayValue $unit';
        }
        return displayValue;
      }
    }
    // Обработка Map (например {value: "каша"} или blood_pressure)
    if (value is Map) {
      // Для blood_pressure
      if (entry.parameterKey == 'blood_pressure') {
        log.d('_formatEntryValue: blood_pressure raw value = $value');
        dynamic bpValue = value;

        // Рекурсивно извлекаем вложенные значения {value: {value: {...}}}
        while (bpValue is Map &&
            bpValue.containsKey('value') &&
            bpValue['value'] is Map) {
          log.d('_formatEntryValue: unwrapping, current = $bpValue');
          bpValue = bpValue['value'];
        }

        log.d('_formatEntryValue: final bpValue = $bpValue');

        // Если после извлечения получили Map с ключом 'value' и строковым значением
        if (bpValue is Map &&
            bpValue.containsKey('value') &&
            bpValue['value'] is String) {
          final stringValue = bpValue['value'] as String;
          log.d('_formatEntryValue: Found string value: $stringValue');

          // Парсим строку формата "120/80 мм рт.ст." или "120/80"
          final match = RegExp(r'(\d+)/(\d+)').firstMatch(stringValue);
          if (match != null) {
            final systolic = int.tryParse(match.group(1) ?? '0') ?? 0;
            final diastolic = int.tryParse(match.group(2) ?? '0') ?? 0;
            log.d(
              '_formatEntryValue: Parsed from string: systolic=$systolic, diastolic=$diastolic',
            );

            if (systolic == 0 && diastolic == 0) {
              return '—';
            }
            return '$systolic/$diastolic мм рт.ст.';
          }
          // Если не удалось распарсить, возвращаем как есть
          return stringValue;
        }

        if (bpValue is Map) {
          final systolic = bpValue['systolic'] ?? bpValue['sys'] ?? 0;
          final diastolic = bpValue['diastolic'] ?? bpValue['dia'] ?? 0;

          log.d('_formatEntryValue: systolic=$systolic, diastolic=$diastolic');

          // Если оба значения 0, возможно данные не были сохранены
          if (systolic == 0 && diastolic == 0) {
            log.w('_formatEntryValue: Both values are 0');
            return '—';
          }

          return '$systolic/$diastolic мм рт.ст.';
        }

        log.w('_formatEntryValue: bpValue is not a Map after unwrapping');
        return '—';
      }

      // Попытка вывести все значения из Map (только не null и не пустые)
      if (value is Map) {
        final mapValues = value.values
            .where((v) => v != null)
            .map((v) => v.toString())
            .where((s) => s.isNotEmpty && !s.startsWith('{'))
            .toList();

        if (mapValues.isNotEmpty) {
          return mapValues.join(', ');
        }
      }

      return '—';
    }

    // Обработка строк "true"/"false" (кроме показателей времени)
    if (value is String && !timeParams.contains(entry.parameterKey)) {
      final lowerValue = value.toLowerCase();
      if (lowerValue == 'true') return 'Было';
      if (lowerValue == 'false') return 'Не было';
      if (value == '1') return 'Было';
      if (value == '0') return 'Не было';

      // Проверка на JSON-подобные строки типа "{value: каша}" или "{value: значение}"
      if (value.startsWith('{') && value.contains('value:')) {
        // Извлекаем значение из строки формата "{value: значение}"
        final regex = RegExp(r'\{value:\s*(.+?)\}');
        final match = regex.firstMatch(value);
        if (match != null && match.group(1) != null) {
          return match.group(1)!.trim();
        }
      }

      // Другие JSON-подобные строки - не показываем
      if (value.startsWith('{') || value.startsWith('[')) {
        return '—';
      }
    }

    // Стандартное отображение с единицами измерения
    String displayValue = value?.toString() ?? '—';

    // Проверка на случайное отображение Map.toString()
    if (displayValue.startsWith('{') && displayValue.contains(':')) {
      return '—';
    }

    // Не добавляем единицы измерения для пустых значений
    if (displayValue == '—') {
      return displayValue;
    }

    final unit = _getUnitForParameter(entry.parameterKey);
    // Проверяем, не содержит ли значение уже единицу измерения
    if (unit.isNotEmpty && !displayValue.contains(unit)) {
      displayValue = '$displayValue $unit';
    }

    return displayValue;
  }

  /// Получить единицу измерения для параметра
  /// Делегирует вызов в утилиты для централизованного управления
  String _getUnitForParameter(String key) =>
      diary_utils.getUnitForParameter(key);

  Widget _buildRouteSheetTab(BuildContext context) {
    return BlocBuilder<RouteSheetCubit, RouteSheetState>(
      builder: (context, state) {
        final tasksForDate = state.getTasksForDate(state.selectedDate);
        final hasTasks = state.tasks.isNotEmpty;

        if (!hasTasks) {
          // Показываем стандартный UI, если нет задач
          return SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                context.read<RouteSheetCubit>().loadRouteSheet();
                await Future.delayed(const Duration(milliseconds: 500));
              },
              color: AppConfig.primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
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
                      child: Text(
                        'Маршрутный лист показывает, какие манипуляции нужно выполнять с подопечным, когда и с какой периодичностью (ежедневно, раз в неделю). Можно составить вручную или воспользоваться ИИ, который предложит готовый вариант на основе дневника динамики ухода. С маршрутным листом легко согласовать, изменить и отслеживать выполнение всех процедур.',
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Настроить маршрутный лист',
                      style: GoogleFonts.firaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
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
                      child: BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, authState) {
                          // Проверяем роль и тип аккаунта пользователя
                          // Скрываем управление маршрутным листом для:
                          // - пользователя с accountType == 'doctor' или 'caregiver'
                          // - сотрудника-си́делки в организации (hasRole('caregiver'))
                          // - пользователя с accountType == 'client' и ролью 'caregiver'
                          final isDoctorOrCaregiver =
                              authState is AuthAuthenticated &&
                              (authState.user.accountType == 'doctor' ||
                                  authState.user.accountType == 'caregiver');

                          final isOrganizationCaregiver =
                              authState is AuthAuthenticated &&
                              authState.user.hasRole('caregiver');

                          final isClientCaregiver =
                              authState is AuthAuthenticated &&
                              authState.user.accountType == 'client' &&
                              authState.user.hasRole('caregiver');

                          final isCaregiver =
                              isDoctorOrCaregiver ||
                              isOrganizationCaregiver ||
                              isClientCaregiver;

                          // Если сиделка/врач, показываем информацию без кнопок
                          if (isCaregiver) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Маршрутный лист пока не настроен. Обратитесь к администратору для настройки.',
                                  style: GoogleFonts.firaSans(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            );
                          }

                          // Для остальных ролей показываем кнопки
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Добавьте манипуляции вручную или с помощью ИИ',
                                style: GoogleFonts.firaSans(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade800,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  _showManipulationsBottomSheet(context);
                                },
                                child: Text(
                                  'Добавить',
                                  style: GoogleFonts.firaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConfig.primaryColor,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  // TODO: Implement AI add
                                },
                                child: Text(
                                  'Добавить с ИИ',
                                  style: GoogleFonts.firaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Показываем данные в виде временных слотов
        return SafeArea(
          child: Column(
            children: [
              // Дата выбора
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'НАЖМИТЕ, ЧТОБЫ ВЫБРАТЬ ДАТУ ИСТОРИИ ЗАПОЛНЕНИЯ',
                      style: GoogleFonts.firaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isRouteSheetDatePickerExpanded =
                              !_isRouteSheetDatePickerExpanded;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppConfig.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat(
                                'EEEE, d MMMM yг',
                                'ru',
                              ).format(state.selectedDate),
                              style: GoogleFonts.firaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppConfig.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              color: AppConfig.primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isRouteSheetDatePickerExpanded) ...[
                      const SizedBox(height: 16),
                      _buildInlineCalendar(state.selectedDate, (date) {
                        context.read<RouteSheetCubit>().setSelectedDate(date);
                        setState(() {
                          _isRouteSheetDatePickerExpanded = false;
                        });
                      }),
                    ],
                  ],
                ),
              ),
              // Манипуляции на сегодня
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 16,
                  ),
                  padding: const EdgeInsets.all(16),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Манипуляции на сегодня',
                        style: GoogleFonts.firaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(child: _buildTimeSlots(tasksForDate)),
                      const SizedBox(height: 16),
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, authState) {
                          // Скрываем кнопку "Изменить" для:
                          // - пользователя с accountType == 'doctor' или 'caregiver'
                          // - сотрудника-сиделки в организации (hasRole('caregiver'))
                          // - пользователя с accountType == 'client' и ролью 'caregiver'
                          final isDoctorOrCaregiver =
                              authState is AuthAuthenticated &&
                              (authState.user.accountType == 'doctor' ||
                                  authState.user.accountType == 'caregiver');

                          final isOrganizationCaregiver =
                              authState is AuthAuthenticated &&
                              authState.user.hasRole('caregiver');

                          final isClientCaregiver =
                              authState is AuthAuthenticated &&
                              authState.user.accountType == 'client' &&
                              authState.user.hasRole('caregiver');

                          final isCaregiver =
                              isDoctorOrCaregiver ||
                              isOrganizationCaregiver ||
                              isClientCaregiver;

                          if (isCaregiver) {
                            return const SizedBox.shrink();
                          }

                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade800,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () {
                                _showManipulationsBottomSheet(context);
                              },
                              child: Text(
                                'Изменить',
                                style: GoogleFonts.firaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeSlots(List<RouteSheetTask> tasks) {
    // Находим минимальный и максимальный час среди задач
    int minHour = 0; // По умолчанию с 0:00 (24 часа)
    int maxHour = 23; // По умолчанию до 23:00 (24 часа)

    for (var task in tasks) {
      final startParts = task.startTimeFormatted.split(':');
      final endParts = task.endTimeFormatted.split(':');
      if (startParts.isNotEmpty) {
        final startHour = int.tryParse(startParts[0]) ?? 0;
        if (startHour < minHour) minHour = startHour;
      }
      if (endParts.isNotEmpty) {
        final endHour = int.tryParse(endParts[0]) ?? 23;
        if (endHour > maxHour) maxHour = endHour;
      }
    }

    // Убедимся что показываем хотя бы диапазон 0:00 - 23:00 (24 часа)
    if (minHour > 0) minHour = 0;
    if (maxHour < 23) maxHour = 23;

    // Создаем список часов для отображения
    final List<int> hours = List.generate(
      maxHour - minHour + 1,
      (index) => minHour + index,
    );

    // Для каждого часа определяем какие задачи его покрывают
    Map<int, List<RouteSheetTask>> tasksCoveringHour = {};
    Map<int, bool> isTaskStartHour = {};
    Map<int, bool> isTaskEndHour = {};

    for (var hour in hours) {
      tasksCoveringHour[hour] = [];
      for (var task in tasks) {
        final startParts = task.startTimeFormatted.split(':');
        final endParts = task.endTimeFormatted.split(':');

        final startHour = int.tryParse(startParts[0]) ?? 0;
        final endHour = int.tryParse(endParts[0]) ?? 0;

        // Если startHour == endHour (задача в пределах одного часа),
        // то задача покрывает только этот час
        // Иначе задача покрывает часы от startHour до endHour включительно
        final effectiveEndHour = endHour == startHour ? endHour + 1 : endHour;

        // Задача покрывает этот час если startHour <= hour < effectiveEndHour
        if (startHour <= hour && hour < effectiveEndHour) {
          tasksCoveringHour[hour]!.add(task);
          if (startHour == hour) {
            isTaskStartHour[task.id] = true;
          }
          if (hour == effectiveEndHour - 1) {
            isTaskEndHour[task.id] = true;
          }
        }
      }
    }

    return ListView.builder(
      itemCount: hours.length,
      itemBuilder: (context, index) {
        final hour = hours[index];
        final timeSlot = '${hour.toString().padLeft(2, '0')}:00';
        final slotTasks = tasksCoveringHour[hour] ?? [];

        return Padding(
          padding: const EdgeInsets.only(bottom: 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Время
              SizedBox(
                width: 50,
                child: Text(
                  timeSlot,
                  style: GoogleFonts.firaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Задачи
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: slotTasks.isEmpty
                      ? [
                          // Пустой слот
                          Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ]
                      : slotTasks.map((task) {
                          // Определяем это начало, середина или конец задачи
                          final startParts = task.startTimeFormatted.split(':');
                          final endParts = task.endTimeFormatted.split(':');
                          final startHour = int.tryParse(startParts[0]) ?? 0;
                          final endHour = int.tryParse(endParts[0]) ?? 0;

                          // Для одночасовых задач
                          final effectiveEndHour = endHour == startHour
                              ? endHour + 1
                              : endHour;

                          final isStart = startHour == hour;
                          final isEnd = hour == effectiveEndHour - 1;

                          return _buildTaskSlot(
                            context,
                            task,
                            isStart: isStart,
                            isEnd: isEnd,
                          );
                        }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskSlot(
    BuildContext context,
    RouteSheetTask task, {
    required bool isStart,
    required bool isEnd,
  }) {
    // print('Render task ${task.id}: ${task.status}');
    Color backgroundColor;
    String statusText;

    // Check if task is rescheduled first, then apply status colors
    if (task.isRescheduled) {
      backgroundColor = Colors.orange;
      statusText = 'Перенесено';
    } else {
      switch (task.status) {
        case TaskStatus.completed:
          backgroundColor = AppConfig.primaryColor;
          statusText = 'Выполнено';
          break;
        case TaskStatus.pending:
          backgroundColor = const Color(0xFF00BCD4);
          statusText = 'Ожидает';
          break;
        case TaskStatus.cancelled:
          backgroundColor = Colors.orange;
          statusText = 'Отменено';
          break;
        case TaskStatus.missed:
          backgroundColor = Colors.red;
          statusText = 'Пропущено';
          break;
      }
    }

    // Определяем скругления углов
    BorderRadius borderRadius;
    if (isStart && isEnd) {
      borderRadius = BorderRadius.circular(8);
    } else if (isStart) {
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(8),
        topRight: Radius.circular(8),
      );
    } else if (isEnd) {
      borderRadius = const BorderRadius.only(
        bottomLeft: Radius.circular(8),
        bottomRight: Radius.circular(8),
      );
    } else {
      borderRadius = BorderRadius.zero;
    }

    // Определяем, есть ли причина для отображения
    final String? reason = task.comment ?? task.rescheduleReason;
    final bool hasReason =
        reason != null &&
        reason.isNotEmpty &&
        (task.status == TaskStatus.missed ||
            task.status == TaskStatus.cancelled ||
            task.isRescheduled);

    return GestureDetector(
      onTap: () => _showTaskActionsModal(context, task),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
        ),
        child: isStart
            ? Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: GoogleFonts.firaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          if (hasReason) ...[
                            const SizedBox(height: 1),
                            Text(
                              'Причина: $reason',
                              style: GoogleFonts.firaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withOpacity(0.85),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: backgroundColor.withOpacity(0.8),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Text(
                      statusText,
                      style: GoogleFonts.firaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(), // Пустой слот для продолжения задачи
      ),
    );
  }

  void _showTaskActionsModal(BuildContext context, RouteSheetTask task) {
    // Сохраняем контекст страницы для передачи в дочерние диалоги
    final pageContext = context;
    // Получаем кубит из контекста страницы, где провайдер доступен
    final routeSheetCubit = context.read<RouteSheetCubit>();

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Название задачи
              Text(
                task.title,
                style: GoogleFonts.firaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppConfig.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Заголовок
              Text(
                'Выберите действие',
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 16),
              // Кнопка "Задача выполнена"
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();

                    // Определяем тип задачи (по relatedDiaryKey или названию)
                    final taskKey =
                        task.relatedDiaryKey ?? _getKeyFromTitle(task.title);
                    const booleanKeys = {
                      'skin_moisturizing',
                      'hygiene',
                      'defecation',
                      'nausea',
                      'vomiting',
                      'dyspnea',
                      'itching',
                      'cough',
                      'dry_mouth',
                      'hiccup',
                      'taste_disorder',
                      'walk',
                      'urine',
                    };

                    // Для булевых задач открываем диалог "Было / Не было",
                    // чтобы сохранять строго boolean-значение
                    if (booleanKeys.contains(taskKey)) {
                      _showBooleanCompleteDialog(
                        pageContext,
                        task,
                        routeSheetCubit,
                      );
                      return;
                    }

                    // Иначе открываем детализированный диалог ввода значения
                    _showCompleteTaskDialog(pageContext, task, routeSheetCubit);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Задача выполнена',
                    style: GoogleFonts.firaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Кнопка "Перенести задачу"
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    // Используем pageContext для следующего диалога
                    _showRescheduleTaskDialog(
                      pageContext,
                      task,
                      routeSheetCubit,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Перенести задачу',
                    style: GoogleFonts.firaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Кнопка "Задача не выполнена"
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    // Используем pageContext для следующего диалога
                    _showMissTaskDialog(pageContext, task, routeSheetCubit);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Задача не выполнена',
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
        ),
      ),
    );
  }

  void _showCompleteTaskDialog(
    BuildContext context,
    RouteSheetTask task,
    RouteSheetCubit cubit,
  ) {
    // Определяем тип задачи по relatedDiaryKey или title
    final taskKey = task.relatedDiaryKey ?? _getKeyFromTitle(task.title);

    const measurementParams = [
      'blood_pressure',
      'temperature',
      'pulse',
      'saturation',
      'oxygen_saturation',
      'respiratory_rate',
      'pain_level',
    ];

    const textParams = [
      'feeding',
      'cognitive_games',
      'meal',
      'medication',
      'vitamins',
      'blood_sugar',
      'sugar_level',
      'fluid_intake',
      'urine_output',
      'fluid_and_urine',
    ];

    const timeRangeParams = ['sleep'];

    const timeParams = ['diaper_change'];

    if (measurementParams.contains(taskKey)) {
      _showMeasurementCompleteDialog(context, task, cubit, taskKey);
    } else if (textParams.contains(taskKey)) {
      _showTextCompleteDialog(context, task, cubit, taskKey);
    } else if (timeRangeParams.contains(taskKey)) {
      _showTimeRangeCompleteDialog(context, task, cubit);
    } else if (timeParams.contains(taskKey)) {
      _showTimeCompleteDialog(context, task, cubit, taskKey);
    } else {
      // По умолчанию показываем было/не было
      _showBooleanCompleteDialog(context, task, cubit);
    }
  }

  /// Получить ключ показателя из названия задачи
  String _getKeyFromTitle(String title) {
    const titleToKey = {
      'Прогулка': 'walk',
      'Давление': 'blood_pressure',
      'Артериальное давление': 'blood_pressure',
      'Измерение давления': 'blood_pressure',
      'Температура': 'temperature',
      'Пульс': 'pulse',
      'Сатурация': 'saturation',
      'Частота дыхания': 'respiratory_rate',
      'Смена подгузников': 'diaper_change',
      'Увлажнение кожи': 'skin_moisturizing',
      'Приём лекарств': 'medication',
      'Прием лекарств': 'medication', // Вариант без ё
      'Лекарства': 'medication',
      'Кормление': 'feeding',
      'Прием пищи': 'meal',
      'Приём пищи': 'meal',
      'Выпито жидкости': 'fluid_intake',
      'Выделено мочи': 'urine_output',
      'Выделение мочи': 'urine',
      'Выпито/выделено и цвет мочи': 'fluid_and_urine',
      'Дефекация': 'defecation',
      'Гигиена': 'hygiene',
      'Когнитивные игры': 'cognitive_games',
      'Приём витаминов': 'vitamins',
      'Прием витаминов': 'vitamins', // Вариант без ё
      'Витамины': 'vitamins',
      'Сон': 'sleep',
      'Уровень боли': 'pain_level',
      'Уровень сахара': 'blood_sugar',
      'Уровень сахара в крови': 'blood_sugar',
      'Тошнота': 'nausea',
      'Одышка': 'dyspnea',
      'Кашель': 'cough',
      'Икота': 'hiccup',
      'Рвота': 'vomiting',
      'Зуд': 'itching',
      'Сухость во рту': 'dry_mouth',
      'Нарушение вкуса': 'taste_disorder',
    };
    return titleToKey[title] ?? 'walk';
  }

  /// Диалог выполнения для булевых показателей (было/не было)
  void _showBooleanCompleteDialog(
    BuildContext context,
    RouteSheetTask task,
    RouteSheetCubit cubit,
  ) {
    final pageContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                task.title,
                style: GoogleFonts.firaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppConfig.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Отметьте, было ли выполнено',
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        await cubit.completeTask(
                          taskId: task.id,
                          value: {'value': true},
                        );
                        // Обновляем историю (дневник)
                        if (pageContext.mounted) {
                          pageContext.read<DiaryBloc>().add(
                            LoadDiary(widget.diaryId),
                          );
                          ScaffoldMessenger.of(pageContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Задача отмечена как выполненная',
                                style: GoogleFonts.firaSans(),
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Было',
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        await cubit.completeTask(
                          taskId: task.id,
                          value: {'value': false},
                        );
                        // Обновляем историю (дневник)
                        if (pageContext.mounted) {
                          pageContext.read<DiaryBloc>().add(
                            LoadDiary(widget.diaryId),
                          );
                          ScaffoldMessenger.of(pageContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Задача отмечена как выполненная',
                                style: GoogleFonts.firaSans(),
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Не было',
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
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

  /// Диалог выполнения для показателей с измерениями
  void _showMeasurementCompleteDialog(
    BuildContext context,
    RouteSheetTask task,
    RouteSheetCubit cubit,
    String taskKey,
  ) {
    final pageContext = context;
    final controller = TextEditingController();
    final controller2 =
        TextEditingController(); // Для давления (диастолическое)
    final unit = _getUnitForParameter(taskKey);
    final isBloodPressure = taskKey == 'blood_pressure';

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                task.title,
                style: GoogleFonts.firaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppConfig.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Введите значение измерения',
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (isBloodPressure) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: 'Систолическое',
                          hintText: '120',
                          suffixText: 'мм',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppConfig.primaryColor,
                            ),
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
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: 'Диастолическое',
                          hintText: '80',
                          suffixText: 'мм',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppConfig.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'Значение',
                    suffixText: unit,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppConfig.primaryColor),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Отмена',
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        String value;
                        if (isBloodPressure) {
                          final sys = controller.text.trim();
                          final dia = controller2.text.trim();
                          if (sys.isEmpty || dia.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text('Введите оба значения'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          value = '$sys/$dia мм рт.ст.';
                        } else {
                          value = controller.text.trim();
                          if (value.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text('Введите значение'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          if (unit.isNotEmpty) {
                            value = '$value $unit';
                          }
                        }

                        Navigator.of(dialogContext).pop();

                        await cubit.completeTask(
                          taskId: task.id,
                          value: {'value': value},
                        );
                        // Обновляем историю (дневник)
                        if (pageContext.mounted) {
                          pageContext.read<DiaryBloc>().add(
                            LoadDiary(widget.diaryId),
                          );
                          ScaffoldMessenger.of(pageContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Задача отмечена как выполненная',
                                style: GoogleFonts.firaSans(),
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConfig.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Сохранить',
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
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

  /// Диалог выполнения для текстовых показателей
  void _showTextCompleteDialog(
    BuildContext context,
    RouteSheetTask task,
    RouteSheetCubit cubit,
    String taskKey,
  ) {
    final pageContext = context;
    final controller = TextEditingController();

    String hint = '';
    if (taskKey == 'feeding' || taskKey == 'meal') {
      hint = 'Например: завтрак — овсянка, чай';
    } else if (taskKey == 'cognitive_games') {
      hint = 'Например: шахматы, чтение книги';
    } else if (taskKey == 'medication' || taskKey == 'vitamins') {
      hint = 'Например: парацетамол, витамин D';
    } else if (taskKey == 'blood_sugar' || taskKey == 'sugar_level') {
      hint = 'Например: 5.5 ммоль/л или нормально';
    } else if (taskKey == 'fluid_intake') {
      hint = 'Например: 200 мл или 1 стакан';
    } else if (taskKey == 'urine_output') {
      hint = 'Например: 150 мл или много';
    } else if (taskKey == 'fluid_and_urine') {
      hint = 'Например: выпито 200 мл, выделено 150 мл, цвет светло-желтый';
    }

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                task.title,
                style: GoogleFonts.firaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppConfig.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Опишите подробности',
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: hint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Отмена',
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final value = controller.text.trim();
                        if (value.isEmpty) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text('Введите описание'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        Navigator.of(dialogContext).pop();

                        await cubit.completeTask(
                          taskId: task.id,
                          value: {'value': value},
                        );
                        // Обновляем историю (дневник)
                        if (pageContext.mounted) {
                          pageContext.read<DiaryBloc>().add(
                            LoadDiary(widget.diaryId),
                          );
                          ScaffoldMessenger.of(pageContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Задача отмечена как выполненная',
                                style: GoogleFonts.firaSans(),
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConfig.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Сохранить',
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
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

  /// Диалог выполнения для показателей с выбором времени (смена подгузников)
  void _showTimeCompleteDialog(
    BuildContext context,
    RouteSheetTask task,
    RouteSheetCubit cubit,
    String taskKey,
  ) {
    final pageContext = context;
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.title,
                  style: GoogleFonts.firaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppConfig.primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Укажите время выполнения',
                  style: GoogleFonts.firaSans(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () async {
                    final time = await showTimePickerModal(
                      context: ctx,
                      title: 'Выберите время',
                      description: 'Время начала',
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      setModalState(() => selectedTime = time);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 24,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.access_time, color: AppConfig.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          selectedTime != null
                              ? selectedTime!.format(ctx)
                              : 'Выбрать время',
                          style: GoogleFonts.firaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: selectedTime != null
                                ? Colors.grey.shade900
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
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
                        onPressed: selectedTime != null
                            ? () async {
                                Navigator.pop(ctx);
                                await cubit.completeTask(
                                  taskId: task.id,
                                  value: {'value': selectedTime!.format(ctx)},
                                );
                                // Обновляем историю (дневник)
                                if (pageContext.mounted) {
                                  pageContext.read<DiaryBloc>().add(
                                    LoadDiary(widget.diaryId),
                                  );
                                  ScaffoldMessenger.of(
                                    pageContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Задача отмечена как выполненная',
                                        style: GoogleFonts.firaSans(),
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
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

  /// Диалог выполнения для показателей с диапазоном времени (сон)
  void _showTimeRangeCompleteDialog(
    BuildContext context,
    RouteSheetTask task,
    RouteSheetCubit cubit,
  ) {
    final pageContext = context;
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.title,
                  style: GoogleFonts.firaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppConfig.primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Укажите время начала и окончания',
                  style: GoogleFonts.firaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final time = await showTimePickerModal(
                            context: context,
                            title: 'Выберите время',
                            description: 'Время начала',
                            initialTime: startTime ?? TimeOfDay.now(),
                          );
                          if (time != null) {
                            setDialogState(() => startTime = time);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.access_time,
                                color: AppConfig.primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                startTime != null
                                    ? '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}'
                                    : 'Начало',
                                style: GoogleFonts.firaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: startTime != null
                                      ? Colors.grey.shade900
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '—',
                        style: GoogleFonts.firaSans(
                          fontSize: 20,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final time = await showTimePickerModal(
                            context: context,
                            title: 'Выберите время',
                            description: 'Время окончания',
                            initialTime: endTime ?? TimeOfDay.now(),
                          );
                          if (time != null) {
                            setDialogState(() => endTime = time);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.access_time,
                                color: AppConfig.primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                endTime != null
                                    ? '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}'
                                    : 'Конец',
                                style: GoogleFonts.firaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: endTime != null
                                      ? Colors.grey.shade900
                                      : Colors.grey.shade500,
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
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Отмена',
                          style: GoogleFonts.firaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (startTime == null || endTime == null) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Укажите время начала и окончания',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          final startStr =
                              '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}';
                          final endStr =
                              '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}';
                          final value = '$startStr — $endStr';

                          Navigator.of(dialogContext).pop();
                          await cubit.completeTask(
                            taskId: task.id,
                            value: {'value': value},
                          );
                          // Обновляем историю (дневник)
                          if (pageContext.mounted) {
                            pageContext.read<DiaryBloc>().add(
                              LoadDiary(widget.diaryId),
                            );
                            ScaffoldMessenger.of(pageContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Задача отмечена как выполненная',
                                  style: GoogleFonts.firaSans(),
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Сохранить',
                          style: GoogleFonts.firaSans(
                            fontSize: 14,
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

  void _showRescheduleTaskDialog(
    BuildContext context,
    RouteSheetTask task,
    RouteSheetCubit cubit,
  ) {
    final reasonController = TextEditingController();
    TimeOfDay? newStartTime;
    TimeOfDay? newEndTime;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.title,
                  style: GoogleFonts.firaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppConfig.primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Текущее время: ${task.timeRange}',
                  style: GoogleFonts.firaSans(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                // Выбор нового времени начала
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Новое время начала:',
                            style: GoogleFonts.firaSans(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final time = await showTimePickerModal(
                                context: context,
                                title: 'Выберите время',
                                description: 'Время начала',
                                initialTime: TimeOfDay.fromDateTime(
                                  task.startAt,
                                ),
                              );
                              if (time != null) {
                                setDialogState(() {
                                  newStartTime = time;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 18,
                                    color: AppConfig.primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    newStartTime != null
                                        ? '${newStartTime!.hour.toString().padLeft(2, '0')}:${newStartTime!.minute.toString().padLeft(2, '0')}'
                                        : 'Выбрать',
                                    style: GoogleFonts.firaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Новое время окончания:',
                            style: GoogleFonts.firaSans(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final time = await showTimePickerModal(
                                context: context,
                                title: 'Выберите время',
                                description: 'Время окончания',
                                initialTime: TimeOfDay.fromDateTime(task.endAt),
                              );
                              if (time != null) {
                                setDialogState(() {
                                  newEndTime = time;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 18,
                                    color: AppConfig.primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    newEndTime != null
                                        ? '${newEndTime!.hour.toString().padLeft(2, '0')}:${newEndTime!.minute.toString().padLeft(2, '0')}'
                                        : 'Выбрать',
                                    style: GoogleFonts.firaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Причина переноса:',
                  style: GoogleFonts.firaSans(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    hintText: 'Напишите причину',
                    hintStyle: GoogleFonts.firaSans(
                      color: Colors.grey.shade400,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: GoogleFonts.firaSans(),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // Валидация
                          if (newStartTime == null || newEndTime == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Выберите новое время',
                                  style: GoogleFonts.firaSans(),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          if (reasonController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Укажите причину переноса',
                                  style: GoogleFonts.firaSans(),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          // Создаём новые DateTime с выбранным временем
                          final newStartAt = DateTime(
                            task.startAt.year,
                            task.startAt.month,
                            task.startAt.day,
                            newStartTime!.hour,
                            newStartTime!.minute,
                          );
                          final newEndAt = DateTime(
                            task.endAt.year,
                            task.endAt.month,
                            task.endAt.day,
                            newEndTime!.hour,
                            newEndTime!.minute,
                          );

                          Navigator.pop(dialogContext);

                          try {
                            await cubit.rescheduleTask(
                              taskId: task.id,
                              startAt: newStartAt,
                              endAt: newEndAt,
                              reason: reasonController.text,
                            );
                            if (this.context.mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Задача успешно перенесена',
                                    style: GoogleFonts.firaSans(),
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          } catch (e) {
                            if (this.context.mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Ошибка: $e',
                                    style: GoogleFonts.firaSans(),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Перенести',
                          style: GoogleFonts.firaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Отмена',
                          style: GoogleFonts.firaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900,
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

  void _showMissTaskDialog(
    BuildContext context,
    RouteSheetTask task,
    RouteSheetCubit cubit,
  ) {
    // Сохраняем контекст страницы для snackbar
    final pageContext = context;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                task.title,
                style: GoogleFonts.firaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppConfig.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Напишите причину отмены задачи',
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: 'Напишите причину',
                  hintStyle: GoogleFonts.firaSans(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: GoogleFonts.firaSans(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        if (reasonController.text.isEmpty) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Пожалуйста, укажите причину',
                                style: GoogleFonts.firaSans(),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        // Закрываем диалог
                        Navigator.of(dialogContext).pop();

                        // Помечаем задачу как невыполненную
                        await cubit.missTask(
                          taskId: task.id,
                          reason: reasonController.text,
                        );

                        // Перезагружаем данные для обновления UI
                        await cubit.loadRouteSheet();

                        // Показываем snackbar используя контекст страницы
                        if (pageContext.mounted) {
                          ScaffoldMessenger.of(pageContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Задача помечена как невыполненная',
                                style: GoogleFonts.firaSans(),
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Сохранить',
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Отмена',
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
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

  Widget _buildClientTab(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          context.read<DiaryBloc>().add(LoadDiary(widget.diaryId));
          await _loadDiaryOwnerClient();
          await Future.delayed(const Duration(milliseconds: 500));
        },
        color: AppConfig.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDiaryOwnerClientCard(),
              const SizedBox(height: 16),
              // Share diary card
              Container(
                padding: const EdgeInsets.all(20),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Поделитесь дневником с клиентом',
                      style: GoogleFonts.firaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Отправьте ссылку клиенту, чтобы он получил доступ к карточке подопечного и дневнику. Ссылка сохранится в его личном кабинете.',
                      style: GoogleFonts.firaSans(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Create link card
              Container(
                padding: const EdgeInsets.all(20),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_clientInviteUrl == null)
                      Text(
                        'Пока приглашение не создано. Нажмите кнопку ниже, чтобы сформировать персональное приглашение для клиента.',
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      )
                    else ...[
                      Text(
                        'Приглашение создано. Отправьте ссылку клиенту:',
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                _clientInviteUrl!,
                                style: GoogleFonts.firaSans(
                                  fontSize: 12,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              color: AppConfig.primaryColor,
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: _clientInviteUrl!),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Ссылка скопирована в буфер обмена',
                                        style: GoogleFonts.firaSans(),
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: InkWell(
                        onTap: !_isCreatingInvitation
                            ? () => _createClientInvitation(context)
                            : null,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors:
                                  _isCreatingInvitation ||
                                      _clientInviteUrl != null
                                  ? [Colors.grey, Colors.grey.shade400]
                                  : [
                                      AppConfig.primaryColor,
                                      AppConfig.primaryColor.withOpacity(0.8),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: _isCreatingInvitation
                              ? Center(
                                  child: SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                    ),
                                  ),
                                )
                              : Text(
                                  _clientInviteUrl == null
                                      ? 'Создать приглашение'
                                      : 'Создать новое приглашение',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.firaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiaryOwnerClientCard() {
    if (_isLoadingDiaryOwner) {
      return Container(
        padding: const EdgeInsets.all(20),
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
        child: Row(
          children: [
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Загрузка владельца дневника...',
              style: GoogleFonts.firaSans(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    if (_diaryOwnerError != null) {
      return Container(
        padding: const EdgeInsets.all(20),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Не удалось загрузить владельца дневника',
              style: GoogleFonts.firaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Проверьте подключение и попробуйте снова.',
              style: GoogleFonts.firaSans(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _loadDiaryOwnerClient,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Повторить',
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final ownerClient = _diaryOwnerClients.isNotEmpty
        ? _diaryOwnerClients.first
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Клиент',
            style: GoogleFonts.firaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 12),
          if (ownerClient == null)
            Text(
              'Владелец не указан.',
              style: GoogleFonts.firaSans(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            )
          else ...[
            Text(
              ownerClient.fullName,
              style: GoogleFonts.firaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade900,
              ),
            ),
            if (ownerClient.phone != null && ownerClient.phone!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                ownerClient.phone!,
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _createClientInvitation(BuildContext context) async {
    setState(() {
      _isCreatingInvitation = true;
    });

    try {
      final result = await invitationRepository.createClientInvitation(
        patientId: widget.patientId,
      );

      final inviteUrl = result['invite_url'] as String?;

      if (inviteUrl != null) {
        // Заменяем localhost на правильный домен
        final correctedUrl = inviteUrl
            .replaceAll('localhost:3000', 'https://клиент.системыздоровья.рф')
            .replaceAll(
              'http://localhost:3000',
              'https://клиент.системыздоровья.рф',
            )
            .replaceAll(
              'https://localhost:3000',
              'https://клиент.системыздоровья.рф',
            )
            .replaceAll('api.sistemizdorovya.ru', 'клиент.системыздоровья.рф');

        setState(() {
          _clientInviteUrl = correctedUrl;
          _isCreatingInvitation = false;
        });

        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: const Text('Успешно'),
          description: const Text('Приглашение создано'),
          autoCloseDuration: const Duration(seconds: 2),
        );
      } else {
        throw Exception('Ссылка не получена от сервера');
      }
    } catch (e) {
      setState(() {
        _isCreatingInvitation = false;
      });

      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        title: const Text('Ошибка'),
        description: Text(
          e is ForbiddenException ||
                  e.toString().contains('Forbidden') ||
                  e.toString().contains('403')
              ? 'Недостаточно прав для создания приглашения'
              : e is ConflictException || e.toString().contains('409')
              ? 'Дневник не создан или клиент уже привязан'
              : e is ValidationException || e.toString().contains('422')
              ? 'Проверьте корректность данных пациента'
              : 'Не удалось создать приглашение: ${e.toString()}',
        ),
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }

  void _showManipulationsBottomSheet(BuildContext context) {
    final Set<String> selectedManipulations = {};
    final TextEditingController careIndicatorController =
        TextEditingController();
    final TextEditingController physicalIndicatorController =
        TextEditingController();

    // Списки для пользовательских манипуляций
    final List<String> customCareManipulations = [];
    final List<String> customPhysicalManipulations = [];

    // Получаем RouteSheetCubit до открытия модального окна
    final routeSheetCubit = context.read<RouteSheetCubit>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Выбор манипуляций',
                      style: GoogleFonts.firaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppConfig.primaryColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
              ),
              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Чтобы выбрать манипуляции, которые необходимо выполнять специалисту, выберите их, укажите дни, по которым нужно проводить а также порядок выполнения',
                  style: GoogleFonts.firaSans(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Манипуляции ухода
                      Text(
                        'Манипуляции ухода',
                        style: GoogleFonts.firaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            [
                              'Прогулка',
                              'Когнитивные игры',
                              'Смена подгузников',
                              'Гигиена',
                              'Увлажнение кожи',
                              'Прием пищи',
                              'Прием лекарств',
                              'Прием витаминов',
                              ...customCareManipulations,
                            ].map((item) {
                              final isSelected = selectedManipulations.contains(
                                item,
                              );
                              final isCustom = customCareManipulations.contains(
                                item,
                              );
                              return GestureDetector(
                                onTap: () {
                                  _showManipulationSettingsModal(
                                    context,
                                    item,
                                    (shouldAdd) {
                                      setModalState(() {
                                        if (shouldAdd) {
                                          selectedManipulations.add(item);
                                        } else {
                                          selectedManipulations.remove(item);
                                        }
                                      });
                                    },
                                    routeSheetCubit,
                                    isCustom,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppConfig.primaryColor.withOpacity(
                                            0.1,
                                          )
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppConfig.primaryColor
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item,
                                        style: GoogleFonts.firaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? AppConfig.primaryColor
                                              : Colors.grey.shade900,
                                        ),
                                      ),
                                      if (isCustom) ...[
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () {
                                            setModalState(() {
                                              customCareManipulations.remove(
                                                item,
                                              );
                                              selectedManipulations.remove(
                                                item,
                                              );
                                            });
                                          },
                                          child: Icon(
                                            Icons.close,
                                            size: 16,
                                            color: isSelected
                                                ? AppConfig.primaryColor
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 16),
                      // Добавить показатель для ухода
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: careIndicatorController,
                              decoration: InputDecoration(
                                hintText: 'Введите название показателя',
                                hintStyle: GoogleFonts.firaSans(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              style: GoogleFonts.firaSans(
                                fontSize: 14,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              if (careIndicatorController.text.isNotEmpty) {
                                setModalState(() {
                                  customCareManipulations.add(
                                    careIndicatorController.text.trim(),
                                  );
                                });
                                careIndicatorController.clear();
                              }
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppConfig.primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Физические манипуляции
                      Text(
                        'Физические манипуляции',
                        style: GoogleFonts.firaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            [
                              'Температура',
                              'Артериальное давление',
                              'Частота дыхания',
                              'Уровень боли',
                              'Сатурация',
                              'Уровень сахара в крови',
                              'Выпито/выделено и цвет мочи',
                              'Дефекация',
                              'Пульс',
                              ...customPhysicalManipulations,
                            ].map((item) {
                              final isSelected = selectedManipulations.contains(
                                item,
                              );
                              final isCustom = customPhysicalManipulations
                                  .contains(item);
                              return GestureDetector(
                                onTap: () {
                                  _showManipulationSettingsModal(
                                    context,
                                    item,
                                    (shouldAdd) {
                                      setModalState(() {
                                        if (shouldAdd) {
                                          selectedManipulations.add(item);
                                        } else {
                                          selectedManipulations.remove(item);
                                        }
                                      });
                                    },
                                    routeSheetCubit,
                                    isCustom,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppConfig.primaryColor.withOpacity(
                                            0.1,
                                          )
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppConfig.primaryColor
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item,
                                        style: GoogleFonts.firaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? AppConfig.primaryColor
                                              : Colors.grey.shade900,
                                        ),
                                      ),
                                      if (isCustom) ...[
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () {
                                            setModalState(() {
                                              customPhysicalManipulations
                                                  .remove(item);
                                              selectedManipulations.remove(
                                                item,
                                              );
                                            });
                                          },
                                          child: Icon(
                                            Icons.close,
                                            size: 16,
                                            color: isSelected
                                                ? AppConfig.primaryColor
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 16),
                      // Добавить показатель для физических
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: physicalIndicatorController,
                              decoration: InputDecoration(
                                hintText: 'Введите название показателя',
                                hintStyle: GoogleFonts.firaSans(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              style: GoogleFonts.firaSans(
                                fontSize: 14,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              if (physicalIndicatorController.text.isNotEmpty) {
                                setModalState(() {
                                  customPhysicalManipulations.add(
                                    physicalIndicatorController.text.trim(),
                                  );
                                });
                                physicalIndicatorController.clear();
                              }
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppConfig.primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              // Bottom button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Handle selected manipulations
                      context.pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Выбрать',
                      style: GoogleFonts.firaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
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

  void _showManipulationSettingsModal(
    BuildContext context,
    String manipulationName,
    Function(bool shouldAdd) onSave,
    RouteSheetCubit routeSheetCubit,
    bool isCustom,
  ) {
    final timeFromController = TextEditingController();
    final timeToController = TextEditingController();
    final timeMaskFormatter = MaskTextInputFormatter(
      mask: '##:##',
      filter: {"#": RegExp(r'[0-9]')},
    );

    // Сохраняем контекст страницы для передачи в дочерние диалоги
    final pageContext = context;
    // Получаем кубит из контекста страницы, где провайдер доступен
    final routeSheetCubit = context.read<RouteSheetCubit>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<RouteSheetCubit>(),
        child: ManipulationSettingsModalContent(
          manipulationName: manipulationName,
          onSave: onSave,
          timeFromController: timeFromController,
          timeToController: timeToController,
          timeMaskFormatter: timeMaskFormatter,
          routeSheetCubit: routeSheetCubit,
          isCustom: isCustom,
        ),
      ),
    ).then((_) {
      // Dispose контроллеров только после полного закрытия модалки
      try {
        timeFromController.dispose();
        timeToController.dispose();
      } catch (e) {
        // Already disposed or still in use
      }
    });
  }

  Widget _buildAlarmTab(BuildContext context) {
    return AlarmTab(diaryId: widget.diaryId);
  }
}

class _HealthDiaryHintOverlay extends StatelessWidget {
  const _HealthDiaryHintOverlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) {
          final fadeProgress = Curves.easeOutCubic.transform(progress);
          final bounceProgress = Curves.elasticOut.transform(progress);
          final childOffset = 26 * (1 - fadeProgress);
          final childScale = 0.82 + (0.18 * bounceProgress);

          return Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HealthDiaryHintOverlayPainter(
                      progress: fadeProgress,
                    ),
                  ),
                ),
                SafeArea(
                  child: Transform.translate(
                    offset: Offset(0, childOffset),
                    child: Transform.scale(
                      scale: childScale,
                      child: Opacity(
                        opacity: fadeProgress,
                        child: Align(alignment: Alignment.center, child: child),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HealthDiaryHintOverlayPainter extends CustomPainter {
  const _HealthDiaryHintOverlayPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.58 * progress)
      ..style = PaintingStyle.fill;

    canvas.drawPath(overlayPath, paint);
  }

  @override
  bool shouldRepaint(covariant _HealthDiaryHintOverlayPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _HealthDiaryIntroTooltip extends StatelessWidget {
  const _HealthDiaryIntroTooltip({required this.onConfirm});

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final tooltipWidth = (MediaQuery.sizeOf(context).width - 48).clamp(
      260.0,
      360.0,
    );

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: tooltipWidth,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF65B8C8), Color(0xFF2E8298)],
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Это дневник здоровья',
                textAlign: TextAlign.center,
                style: GoogleFonts.firaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.15,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Здесь вы можете:\n'
                '• записывать показатели здоровья\n'
                '• получать напоминания о важных\nдействиях\n'
                '• видеть записи в одном месте\n'
                '• делиться доступом с близкими или\nспециалистами по уходу',
                textAlign: TextAlign.center,
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.2,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 170,
                child: FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppConfig.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Понятно',
                    style: GoogleFonts.firaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
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
}

// Tooltip classes removed (showcaseview dependency removed)
class _HealthDiaryPinnedIndicatorsTooltip extends StatelessWidget {
  const _HealthDiaryPinnedIndicatorsTooltip();

  @override
  Widget build(BuildContext context) {
    final tooltipWidth = (MediaQuery.sizeOf(context).width - 48).clamp(
      260.0,
      380.0,
    );

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: tooltipWidth,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF65B8C8), Color(0xFF2E8298)],
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Это показатели, которые\nнужно заполнять\nрегулярно.',
                textAlign: TextAlign.center,
                style: GoogleFonts.firaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.1,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'По ним приходят напоминания.\n\nНажмите “Заполнить”, чтобы\nзаписать показатель',
                textAlign: TextAlign.center,
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.2,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthDiaryPinnedValueTooltip extends StatelessWidget {
  const _HealthDiaryPinnedValueTooltip();

  @override
  Widget build(BuildContext context) {
    return const _HealthDiaryStepTooltip(text: 'Введите значение\nпоказателя');
  }
}

class _HealthDiaryPinnedTimeTooltip extends StatelessWidget {
  const _HealthDiaryPinnedTimeTooltip();

  @override
  Widget build(BuildContext context) {
    return const _HealthDiaryStepTooltip(
      text:
          'Впишите время, когда нужно напоминать\nо заполнении показателя и нажмите +,\nчтобы добавить',
    );
  }
}

class _HealthDiaryPinnedSaveTooltip extends StatelessWidget {
  const _HealthDiaryPinnedSaveTooltip();

  @override
  Widget build(BuildContext context) {
    return const _HealthDiaryStepTooltip(text: 'Нажмите сохранить');
  }
}

class _HealthDiaryAllIndicatorsTooltip extends StatelessWidget {
  const _HealthDiaryAllIndicatorsTooltip();

  @override
  Widget build(BuildContext context) {
    final tooltipWidth = (MediaQuery.sizeOf(context).width - 40).clamp(
      240.0,
      360.0,
    );

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: tooltipWidth,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF65B8C8), Color(0xFF2E8298)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Эти показатели можно\nзаписывать при\nнеобходимости',
                textAlign: TextAlign.center,
                style: GoogleFonts.firaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.1,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Нажмите на раздел, чтобы открыть\nпоказатели',
                textAlign: TextAlign.center,
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.2,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthDiaryAllIndicatorsSelectTooltip extends StatelessWidget {
  const _HealthDiaryAllIndicatorsSelectTooltip();

  @override
  Widget build(BuildContext context) {
    return const _HealthDiaryStepTooltip(
      text: 'Выберите показатель\nи нажмите на него\nчтобы заполнить',
    );
  }
}

class _HealthDiaryAllIndicatorsCareSaveTooltip extends StatelessWidget {
  const _HealthDiaryAllIndicatorsCareSaveTooltip();

  @override
  Widget build(BuildContext context) {
    return const _HealthDiaryStepTooltip(
      text: 'Заполните показатель и\nнажмите "Сохранить"',
    );
  }
}

class _HealthDiarySavedTooltip extends StatelessWidget {
  const _HealthDiarySavedTooltip();

  @override
  Widget build(BuildContext context) {
    return const _HealthDiaryStepTooltip(text: 'Запись сохранена!');
  }
}

class _HealthDiaryTopSuccessOverlay extends StatelessWidget {
  const _HealthDiaryTopSuccessOverlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                builder: (context, value, _) {
                  final fade = Curves.easeOut.transform(value);
                  return Transform.translate(
                    offset: Offset(0, -18 * (1 - fade)),
                    child: Opacity(opacity: fade, child: child),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HealthDiaryStepTooltip extends StatelessWidget {
  const _HealthDiaryStepTooltip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tooltipWidth = (MediaQuery.sizeOf(context).width - 40).clamp(
      240.0,
      360.0,
    );

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: tooltipWidth,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF65B8C8), Color(0xFF2E8298)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.firaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.15,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
