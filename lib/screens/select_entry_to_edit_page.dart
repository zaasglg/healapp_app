import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../utils/app_icons.dart';
import '../utils/app_logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/diary/diary_event.dart';
import '../bloc/diary/diary_bloc.dart';
import '../repositories/diary_repository.dart';

// Общие списки ключей показателей, используемые в диалогах и хелперах
const List<String> _careIndicatorKeys = [
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

const List<String> _physicalIndicatorKeys = [
  'temperature',
  'blood_pressure',
  'respiratory_rate',
  'pain_level',
  'oxygen_saturation',
  'blood_sugar',
];

const List<String> _excretionIndicatorKeys = ['urine', 'defecation'];

const List<String> _symptomIndicatorKeys = [
  'nausea',
  'dyspnea',
  'cough',
  'hiccup',
  'vomiting',
  'itching',
  'dry_mouth',
  'taste_disorder',
];

String _getIndicatorType(String key) {
  if (_physicalIndicatorKeys.contains(key)) return 'physical';
  if (_careIndicatorKeys.contains(key)) return 'care';
  if (_excretionIndicatorKeys.contains(key)) return 'excretion';
  if (_symptomIndicatorKeys.contains(key)) return 'symptom';
  return 'other';
}

class SelectEntryToEditPage extends StatefulWidget {
  final int diaryId;
  final int patientId;
  final List<DiaryEntry> entries;
  final List<PinnedParameter> pinnedParameters;
  final List<String> allIndicators;

  const SelectEntryToEditPage({
    super.key,
    required this.diaryId,
    required this.patientId,
    required this.entries,
    this.pinnedParameters = const [],
    this.allIndicators = const [],
  });
  static const String routeName = '/select-entry-to-edit';

  @override
  State<SelectEntryToEditPage> createState() => _SelectEntryToEditPageState();
}

class _SelectEntryToEditPageState extends State<SelectEntryToEditPage> {
  final Set<DiaryEntry> _selectedPinnedEntries = {};
  final Set<DiaryEntry> _selectedAllEntries = {};
  final Set<String> _selectedPinnedIndicatorKeys = {};
  final Set<String> _selectedAllIndicatorKeys = {};

  @override
  void initState() {
    super.initState();
    // Предварительно отмечаем записи, которые уже закреплены в дневнике
    final pinnedKeys = widget.pinnedParameters.map((p) => p.key).toSet();
    for (final entry in widget.entries) {
      if (pinnedKeys.contains(entry.parameterKey)) {
        _selectedPinnedEntries.add(entry);
        _selectedAllEntries.add(entry);
      }
    }
    // Initialize selected pinned indicator keys from provided pinnedParameters
    _selectedPinnedIndicatorKeys.addAll(pinnedKeys);
    // Initialize "all" indicator keys from saved allIndicators (settings.all_indicators)
    _selectedAllIndicatorKeys.addAll(widget.allIndicators);
  }

  /// Получить человекочитаемое название показателя по ключу API (используется в диалоге)
  String _getIndicatorLabel(String key) {
    const labels = {
      'blood_pressure': 'Давление',
      'temperature': 'Температура',
      'pulse': 'Пульс',
      'saturation': 'Сатурация',
      'oxygen_saturation': 'Сатурация',
      'respiratory_rate': 'Частота дыхания',
      'diaper_change': 'Смена подгузников',
      'walk': 'Прогулка',
      'skin_moisturizing': 'Увлажнение кожи',
      'medication': 'Приём лекарств',
      'feeding': 'Кормление',
      'meal': 'Прием пищи',
      'fluid_intake': 'Выпито жидкости',
      'urine_output': 'Выделено мочи',
      'urine_color': 'Цвет мочи',
      'urine': 'Выделение мочи',
      'defecation': 'Дефекация',
      'hygiene': 'Гигиена',
      'cognitive_games': 'Когнитивные игры',
      'vitamins': 'Приём витаминов',
      'sleep': 'Сон',
      'pain_level': 'Уровень боли',
      'sugar_level': 'Уровень сахара',
      'blood_sugar': 'Уровень сахара',
      'weight': 'Вес',
      'nausea': 'Тошнота',
      'dyspnea': 'Одышка',
      'cough': 'Кашель',
      'hiccup': 'Икота',
      'vomiting': 'Рвота',
      'itching': 'Зуд',
      'dry_mouth': 'Сухость во рту',
      'taste_disorder': 'Нарушение вкуса',
    };
    return labels[key] ?? key;
  }

  /// Форматирует значение записи для отображения
  String _formatEntryValue(DiaryEntry entry) {
    final value = entry.value;

    // Обработка булевых значений
    if (value is bool) {
      return value ? 'Было' : 'Не было';
    }

    // Обработка Map (например {value: false} или blood_pressure)
    if (value is Map) {
      // Для blood_pressure
      if (entry.parameterKey == 'blood_pressure') {
        dynamic bpValue = value;
        // Если значение вложено в {value: {...}}, извлекаем его
        if (bpValue.containsKey('value') && bpValue['value'] is Map) {
          bpValue = bpValue['value'];
        }
        final systolic = bpValue['systolic'] ?? bpValue['sys'] ?? 0;
        final diastolic = bpValue['diastolic'] ?? bpValue['dia'] ?? 0;
        return '$systolic/$diastolic мм рт.ст.';
      }

      // Для других Map значений - проверяем вложенное value
      if (value.containsKey('value')) {
        final innerValue = value['value'];
        if (innerValue is bool) {
          return innerValue ? 'Было' : 'Не было';
        }
        return innerValue?.toString() ?? '—';
      }

      // Попытка вывести все значения из Map
      return value.values.map((v) => v.toString()).join(', ');
    }

    // Обработка строк "true"/"false"
    if (value is String) {
      final lowerValue = value.toLowerCase();
      if (lowerValue == 'true') return 'Было';
      if (lowerValue == 'false') return 'Не было';
    }

    // Стандартное отображение с единицами измерения
    String displayValue = value?.toString() ?? '—';
    final unit = _getUnitForParameter(entry.parameterKey);
    if (unit.isNotEmpty && displayValue != '—') {
      displayValue = '$displayValue $unit';
    }

    return displayValue;
  }

  String _getUnitForParameter(String key) {
    const units = {
      'temperature': '°C',
      'pulse': 'уд/мин',
      'blood_pressure': 'мм рт.ст.',
      'blood_sugar': 'ммоль/л',
      'weight': 'кг',
      'oxygen_saturation': '%',
      'respiratory_rate': 'дых/мин',
    };
    return units[key] ?? '';
  }

  /// Проверяет, является ли запись закрепленной
  bool _isPinnedEntry(DiaryEntry entry) {
    return widget.pinnedParameters.any(
      (pinned) => pinned.key == entry.parameterKey,
    );
  }

  /// Получает список закрепленных записей
  List<DiaryEntry> get _pinnedEntries {
    final pinnedKeys = widget.pinnedParameters.map((p) => p.key).toSet();
    return widget.entries
        .where((entry) => pinnedKeys.contains(entry.parameterKey))
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  /// Получает список всех остальных записей
  List<DiaryEntry> get _allEntries {
    final pinnedKeys = widget.pinnedParameters.map((p) => p.key).toSet();
    return widget.entries
        .where((entry) => !pinnedKeys.contains(entry.parameterKey))
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  void _openPinnedEntriesDialog() {
    showDialog(
      context: context,
      builder: (context) => _EntriesSelectionDialog(
        title: 'Выбор записей (закрепленные показатели)',
        description:
            'Выберите записи закрепленных показателей для редактирования',
        maxSelection: null,
        maxIndicatorSelection: 3,
        entries: _pinnedEntries,
        selectedEntries: _selectedPinnedEntries,
        blockedEntries: null,
        pinnedParameters: widget.pinnedParameters,
        diaryId: widget.diaryId,
        patientId: widget.patientId,
        initialSelectedIndicatorKeys: widget.pinnedParameters
            .map((p) => p.key)
            .toSet(),
        onSelectionChanged: (selected, selectedKeys) {
          setState(() {
            _selectedPinnedEntries.clear();
            _selectedPinnedEntries.addAll(selected);
            _selectedPinnedIndicatorKeys.clear();
            _selectedPinnedIndicatorKeys.addAll(selectedKeys);
          });
        },
      ),
    );
  }

  void _openAllEntriesDialog() {
    // Получаем ключи закрепленных показателей для блокировки
    final pinnedKeys = widget.pinnedParameters.map((p) => p.key).toSet();
    showDialog(
      context: context,
      builder: (context) => _EntriesSelectionDialog(
        title: 'Выбор записей (все показатели)',
        description: 'Выберите записи для редактирования',
        maxSelection: null,
        maxIndicatorSelection: null,
        entries: _allEntries,
        selectedEntries: _selectedAllEntries,
        blockedEntries: null,
        blockedIndicatorKeys: pinnedKeys, // Блокируем закрепленные показатели
        pinnedParameters: widget.pinnedParameters,
        diaryId: widget.diaryId,
        patientId: widget.patientId,
        initialSelectedIndicatorKeys: widget.allIndicators.toSet(),
        onSelectionChanged: (selected, selectedKeys) {
          setState(() {
            _selectedAllEntries.clear();
            _selectedAllEntries.addAll(selected);
            _selectedAllIndicatorKeys.clear();
            _selectedAllIndicatorKeys.addAll(selectedKeys);
          });
        },
      ),
    );
  }

  void _navigateToEditEntry(DiaryEntry entry) {
    // Open editor and refresh diary when returning
    () async {
      final result = await context.push(
        '/edit-diary-entry',
        extra: {
          'entry': entry,
          'diaryId': widget.diaryId,
          'patientId': widget.patientId,
        },
      );
      if (result == true && context.mounted) {
        context.read<DiaryBloc>().add(LoadDiary(widget.diaryId));
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
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
          'Выберите запись для редактирования',
          style: GoogleFonts.firaSans(
            color: Colors.grey.shade900,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Выберите записи из списка, чтобы отредактировать их значение, заметки или время записи',
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pinned entries section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppConfig.primaryColor,
                            AppConfig.primaryColor.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Закрепленные показатели',
                            style: GoogleFonts.firaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Выберите записи закрепленных показателей для редактирования',
                            style: GoogleFonts.firaSans(
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _openPinnedEntriesDialog,
                            child: Builder(
                              builder: (ctx) {
                                final uniqueSelected = <String>{}
                                  ..addAll(
                                    _selectedPinnedEntries.map(
                                      (e) => e.parameterKey,
                                    ),
                                  )
                                  ..addAll(_selectedPinnedIndicatorKeys);
                                return Text(
                                  'Выбрать (${uniqueSelected.length} / 3)',
                                  style: GoogleFonts.firaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppConfig.primaryColor,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // All entries section
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
                          Text(
                            'Все показатели',
                            style: GoogleFonts.firaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey.shade900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Выберите остальные записи для редактирования',
                            style: GoogleFonts.firaSans(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppConfig.primaryColor),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _openAllEntriesDialog,
                            child: Text(
                              'Выбрать (${_selectedAllIndicatorKeys.length})',
                              style: GoogleFonts.firaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppConfig.primaryColor,
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
          ],
        ),
      ),
    );
  }
}

class _EntriesSelectionDialog extends StatefulWidget {
  final String title;
  final String description;
  final int? maxSelection;
  // Максимальное количество уникальных показателей (ключей). null = без ограничения
  final int? maxIndicatorSelection;
  final List<DiaryEntry> entries;
  final Set<DiaryEntry> selectedEntries;
  final Set<DiaryEntry>? blockedEntries;

  /// Ключи показателей, которые заблокированы для выбора (например, закрепленные)
  final Set<String>? blockedIndicatorKeys;

  /// Текущие закреплённые параметры (для сохранения при обновлении all_indicators)
  final List<PinnedParameter> pinnedParameters;
  final int diaryId;
  final int patientId;
  final Set<String> initialSelectedIndicatorKeys;
  final Function(Set<DiaryEntry>, Set<String>) onSelectionChanged;

  const _EntriesSelectionDialog({
    required this.title,
    required this.description,
    this.maxSelection,
    this.maxIndicatorSelection,
    required this.entries,
    required this.selectedEntries,
    this.blockedEntries,
    this.blockedIndicatorKeys,
    this.pinnedParameters = const [],
    required this.diaryId,
    required this.patientId,
    this.initialSelectedIndicatorKeys = const {},
    required this.onSelectionChanged,
  });

  @override
  State<_EntriesSelectionDialog> createState() =>
      _EntriesSelectionDialogState();
}

class _EntriesSelectionDialogState extends State<_EntriesSelectionDialog> {
  late Set<DiaryEntry> _selectedEntries;
  late Set<String> _selectedIndicatorKeys;

  // Контроллеры для кастомных показателей
  final TextEditingController _careCustomController = TextEditingController();
  final TextEditingController _physicalCustomController =
      TextEditingController();
  final TextEditingController _excretionCustomController =
      TextEditingController();
  final TextEditingController _symptomCustomController =
      TextEditingController();

  // Кастомные показатели для каждой категории
  final Set<String> _customCareIndicators = {};
  final Set<String> _customPhysicalIndicators = {};
  final Set<String> _customExcretionIndicators = {};
  final Set<String> _customSymptomIndicators = {};

  // Категории показателей (ключи API)
  // Категории показателей — используем топ-уровневые константы в файле

  @override
  void initState() {
    super.initState();
    _selectedEntries = Set.from(widget.selectedEntries);
    _selectedIndicatorKeys = Set.from(widget.initialSelectedIndicatorKeys);
  }

  @override
  void dispose() {
    _careCustomController.dispose();
    _physicalCustomController.dispose();
    _excretionCustomController.dispose();
    _symptomCustomController.dispose();
    super.dispose();
  }

  String _getIndicatorLabel(String key) {
    const labels = {
      'blood_pressure': 'Давление',
      'temperature': 'Температура',
      'pulse': 'Пульс',
      'saturation': 'Сатурация',
      'oxygen_saturation': 'Сатурация',
      'respiratory_rate': 'Частота дыхания',
      'diaper_change': 'Смена подгузников',
      'walk': 'Прогулка',
      'skin_moisturizing': 'Увлажнение кожи',
      'medication': 'Приём лекарств',
      'feeding': 'Кормление',
      'meal': 'Прием пищи',
      'fluid_intake': 'Выпито жидкости',
      'urine_output': 'Выделено мочи',
      'urine_color': 'Цвет мочи',
      'urine': 'Выделение мочи',
      'defecation': 'Дефекация',
      'hygiene': 'Гигиена',
      'cognitive_games': 'Когнитивные игры',
      'vitamins': 'Приём витаминов',
      'sleep': 'Сон',
      'pain_level': 'Уровень боли',
      'sugar_level': 'Уровень сахара',
      'blood_sugar': 'Уровень сахара',
      'weight': 'Вес',
      'nausea': 'Тошнота',
      'dyspnea': 'Одышка',
      'cough': 'Кашель',
      'hiccup': 'Икота',
      'vomiting': 'Рвота',
      'itching': 'Зуд',
      'dry_mouth': 'Сухость во рту',
      'taste_disorder': 'Нарушение вкуса',
    };
    return labels[key] ?? key;
  }

  String _formatEntryValue(DiaryEntry entry) {
    final value = entry.value;

    if (value is bool) {
      return value ? 'Было' : 'Не было';
    }

    if (value is Map) {
      if (entry.parameterKey == 'blood_pressure') {
        dynamic bpValue = value;
        // Если значение вложено в {value: {...}}, извлекаем его
        if (bpValue.containsKey('value') && bpValue['value'] is Map) {
          bpValue = bpValue['value'];
        }
        final systolic = bpValue['systolic'] ?? bpValue['sys'] ?? 0;
        final diastolic = bpValue['diastolic'] ?? bpValue['dia'] ?? 0;
        return '$systolic/$diastolic мм рт.ст.';
      }

      if (value.containsKey('value')) {
        final innerValue = value['value'];
        if (innerValue is bool) {
          return innerValue ? 'Было' : 'Не было';
        }
        return innerValue?.toString() ?? '—';
      }

      return value.values.map((v) => v.toString()).join(', ');
    }

    if (value is String) {
      final lowerValue = value.toLowerCase();
      if (lowerValue == 'true') return 'Было';
      if (lowerValue == 'false') return 'Не было';
    }

    return value?.toString() ?? '—';
  }

  /// Подсчитывает количество выбранных показателей (уникальных ключей)
  int _countSelectedIndicators(Map<String, List<DiaryEntry>> groupedEntries) {
    // Считаем уникальные ключи показателей, выбранные либо через записи, либо напрямую
    final selectedKeys = <String>{};
    for (final entry in _selectedEntries) {
      selectedKeys.add(entry.parameterKey);
    }
    selectedKeys.addAll(_selectedIndicatorKeys);
    return selectedKeys.length;
  }

  void _showMaxSelectionDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 48, color: AppConfig.primaryColor),
              const SizedBox(height: 16),
              Text(
                'Достигнут лимит',
                style: GoogleFonts.firaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Можно выбрать не более ${widget.maxIndicatorSelection ?? 3} показателей. Снимите выбор с одного из выбранных показателей, чтобы выбрать другой.',
                textAlign: TextAlign.center,
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Понятно',
                    style: GoogleFonts.firaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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

  void _addCustomIndicator(
    TextEditingController controller,
    Set<String> customSet,
    Map<String, List<DiaryEntry>> groupedEntries,
  ) {
    if (controller.text.trim().isNotEmpty) {
      final indicator = controller.text.trim();
      final totalSelected = _countSelectedIndicators(groupedEntries);
      if (widget.maxIndicatorSelection != null &&
          totalSelected >= widget.maxIndicatorSelection! &&
          !_selectedIndicatorKeys.contains(indicator)) {
        _showMaxSelectionDialog();
        return;
      }
      setState(() {
        _selectedIndicatorKeys.add(indicator);
        customSet.add(indicator);
        controller.clear();
      });
    }
  }

  void _removeCustomIndicator(String indicator, Set<String> customSet) {
    setState(() {
      _selectedIndicatorKeys.remove(indicator);
      customSet.remove(indicator);
    });
  }

  Widget _buildIndicatorSection(
    String title,
    List<String> indicatorKeys,
    TextEditingController customController,
    Set<String> customIndicators,
    Map<String, List<DiaryEntry>> groupedEntries,
  ) {
    final totalSelected = _countSelectedIndicators(groupedEntries);
    final blockedKeys = widget.blockedIndicatorKeys ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: GoogleFonts.firaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.5,
          ),
          itemCount: indicatorKeys.length,
          itemBuilder: (context, index) {
            final indicatorKey = indicatorKeys[index];
            final entries = groupedEntries[indicatorKey] ?? [];
            final hasEntries = entries.isNotEmpty;
            final isEntriesSelected =
                hasEntries &&
                entries.any((entry) => _selectedEntries.contains(entry));
            final isKeySelected = _selectedIndicatorKeys.contains(indicatorKey);
            final isSelected = isEntriesSelected || isKeySelected;
            final isBlocked = blockedKeys.contains(indicatorKey);
            final indicatorLabel = _getIndicatorLabel(indicatorKey);
            final displayLabel = indicatorLabel.replaceAll(
              RegExp(r'\s*\(\d+\)\s*$'),
              '',
            );

            return InkWell(
              onTap: isBlocked
                  ? null // Заблокированные показатели не кликабельны
                  : () {
                      setState(() {
                        // If currently selected (either by entries or by key) -> unselect both
                        if (isSelected) {
                          if (hasEntries) {
                            _selectedEntries.removeAll(entries);
                          }
                          _selectedIndicatorKeys.remove(indicatorKey);
                          return;
                        }

                        // Otherwise select (respecting maxIndicatorSelection)
                        if (hasEntries) {
                          if (widget.maxIndicatorSelection == null ||
                              totalSelected < widget.maxIndicatorSelection!) {
                            _selectedEntries.addAll(entries);
                          } else {
                            _showMaxSelectionDialog();
                          }
                        } else {
                          if (widget.maxIndicatorSelection == null ||
                              totalSelected < widget.maxIndicatorSelection!) {
                            _selectedIndicatorKeys.add(indicatorKey);
                          } else {
                            _showMaxSelectionDialog();
                          }
                        }
                      });
                    },
              child: Opacity(
                opacity: isBlocked ? 0.5 : 1.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isBlocked
                        ? Colors.grey.shade300
                        : (isSelected ? AppConfig.primaryColor : Colors.white),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: isBlocked
                          ? Colors.grey.shade400
                          : (isSelected
                                ? AppConfig.primaryColor
                                : AppConfig.primaryColor.withOpacity(0.3)),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      displayLabel,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.firaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isBlocked
                            ? Colors.grey.shade600
                            : (isSelected
                                  ? Colors.white
                                  : Colors.grey.shade800),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // Кастомные показатели этой категории
        if (customIndicators.isNotEmpty) ...[
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.2,
            ),
            itemCount: customIndicators.length,
            itemBuilder: (context, index) {
              final indicator = customIndicators.elementAt(index);
              return InkWell(
                onTap: () =>
                    _removeCustomIndicator(indicator, customIndicators),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppConfig.primaryColor,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: AppConfig.primaryColor,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            indicator,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.firaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.close, size: 18, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: customController,
                decoration: InputDecoration(
                  hintText: 'Добавить свой показатель',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppConfig.primaryColor.withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppConfig.primaryColor.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onFieldSubmitted: (_) => _addCustomIndicator(
                  customController,
                  customIndicators,
                  groupedEntries,
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                _addCustomIndicator(
                  customController,
                  customIndicators,
                  groupedEntries,
                );
                FocusScope.of(context).unfocus();
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppConfig.primaryColor,
                      AppConfig.primaryColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _toggleEntry(DiaryEntry entry) {
    setState(() {
      if (_selectedEntries.contains(entry)) {
        _selectedEntries.remove(entry);
      } else {
        if (widget.maxSelection != null &&
            _selectedEntries.length >= widget.maxSelection!) {
          return;
        }
        _selectedEntries.add(entry);
      }
    });
  }

  void _confirmSelection() {
    // Сохраняем выбранные записи
    widget.onSelectionChanged(_selectedEntries, _selectedIndicatorKeys);

    // Если выбрана только одна запись, закрываем диалог и переходим к редактированию
    if (_selectedEntries.length == 1) {
      final entry = _selectedEntries.first;
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        () async {
          final result = await context.push(
            '/edit-diary-entry',
            extra: {
              'entry': entry,
              'diaryId': widget.diaryId,
              'patientId': widget.patientId,
            },
          );
          if (result == true && context.mounted) {
            context.read<DiaryBloc>().add(LoadDiary(widget.diaryId));
          }
        }();
      });
    } else {
      // Если выбрано несколько или ничего, просто закрываем диалог
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveSelection() async {
    // Собираем все выбранные показатели (и с записями, и без)
    final selectedKeys = <String>{};

    // Добавляем ключи из выбранных записей
    for (final entry in _selectedEntries) {
      selectedKeys.add(entry.parameterKey);
    }

    // Добавляем ключи без записей
    selectedKeys.addAll(_selectedIndicatorKeys);

    // Добавляем все кастомные показатели
    selectedKeys.addAll(_customCareIndicators);
    selectedKeys.addAll(_customPhysicalIndicators);
    selectedKeys.addAll(_customExcretionIndicators);
    selectedKeys.addAll(_customSymptomIndicators);

    // Создаем список закрепленных параметров
    final pinnedParameters = selectedKeys.map((key) {
      return PinnedParameter(
        key: key,
        intervalMinutes: 60, // Интервал по умолчанию
        times: [],
      );
    }).toList();

    try {
      // Показываем индикатор загрузки
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final repository = DiaryRepository();

      if (widget.maxIndicatorSelection == null) {
        // Это диалог "Все показатели" -> используем PATCH /diary/pinned с settings.all_indicators
        // Собираем все выбранные ключи показателей
        final allIndicatorKeys = <String>{};

        // Добавляем ключи из выбранных записей
        for (final entry in _selectedEntries) {
          allIndicatorKeys.add(entry.parameterKey);
        }

        // Добавляем выбранные ключи без записей
        allIndicatorKeys.addAll(_selectedIndicatorKeys);

        // Добавляем все кастомные показатели
        allIndicatorKeys.addAll(_customCareIndicators);
        allIndicatorKeys.addAll(_customPhysicalIndicators);
        allIndicatorKeys.addAll(_customExcretionIndicators);
        allIndicatorKeys.addAll(_customSymptomIndicators);

        // Вызываем API для сохранения all_indicators
        await repository.saveAllIndicators(
          patientId: widget.patientId,
          allIndicators: allIndicatorKeys.toList(),
          currentPinnedParameters: widget.pinnedParameters,
        );

        // Закрываем индикатор загрузки
        if (mounted) Navigator.of(context).pop();

        // Сохраняем выбранные записи + выбранные ключи показателей
        widget.onSelectionChanged(_selectedEntries, _selectedIndicatorKeys);

        // Закрываем диалог
        if (mounted) Navigator.of(context).pop();

        // Закрываем страницу с результатом true для обновления родительской страницы
        if (mounted) {
          Navigator.of(context).pop(true);
        }

        // Показать успех
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Показатели успешно сохранены',
                style: GoogleFonts.firaSans(),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Это диалог закреплённых показателей -> старое поведение (PATCH /diary/pinned)
        await repository.updatePinnedParameters(
          widget.diaryId,
          pinnedParameters,
        );

        // Закрываем индикатор загрузки
        if (mounted) Navigator.of(context).pop();

        // Сохраняем выбранные записи + выбранные ключи показателей
        widget.onSelectionChanged(_selectedEntries, _selectedIndicatorKeys);

        // Закрываем диалог
        if (mounted) Navigator.of(context).pop();

        // Закрываем страницу с результатом true для обновления родительской страницы
        if (mounted) {
          Navigator.of(context).pop(true);
        }

        // Показываем сообщение об успехе
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Показатели успешно сохранены',
                style: GoogleFonts.firaSans(),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e, st) {
      // Закрываем индикатор загрузки
      if (mounted) Navigator.of(context).pop();

      // Логируем детально в консоль
      print('Ошибка при сохранении закрепленных параметров');
      print('diaryId=${widget.diaryId}, patientId=${widget.patientId}');
      print('Payload: ${pinnedParameters.map((p) => p.toJson()).toList()}');

      // Показываем ошибку пользователю
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ошибка при сохранении: ${e.toString()}',
              style: GoogleFonts.firaSans(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Группируем записи по типу показателя для отображения
    final Map<String, List<DiaryEntry>> groupedEntries = {};
    for (final entry in widget.entries) {
      final key = entry.parameterKey;
      if (!groupedEntries.containsKey(key)) {
        groupedEntries[key] = [];
      }
      groupedEntries[key]!.add(entry);
    }

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          minWidth: MediaQuery.of(context).size.width * 0.92,
        ),
        width: MediaQuery.of(context).size.width * 0.92,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.firaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppConfig.primaryColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.description,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.firaSans(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildIndicatorSection(
                      'Показатели ухода',
                      _careIndicatorKeys,
                      _careCustomController,
                      _customCareIndicators,
                      groupedEntries,
                    ),
                    _buildIndicatorSection(
                      'Физические показатели',
                      _physicalIndicatorKeys,
                      _physicalCustomController,
                      _customPhysicalIndicators,
                      groupedEntries,
                    ),
                    _buildIndicatorSection(
                      'Выделение мочи и кала',
                      _excretionIndicatorKeys,
                      _excretionCustomController,
                      _customExcretionIndicators,
                      groupedEntries,
                    ),
                    _buildIndicatorSection(
                      'Тягостные симптомы',
                      _symptomIndicatorKeys,
                      _symptomCustomController,
                      _customSymptomIndicators,
                      groupedEntries,
                    ),
                  ],
                ),
              ),
            ),
            // Footer button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _saveSelection,
                  child: Text(
                    'Сохранить',
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
    );
  }
}
