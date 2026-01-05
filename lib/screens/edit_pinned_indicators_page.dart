import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:toastification/toastification.dart';
import '../config/app_config.dart';
import '../utils/app_icons.dart';
import '../repositories/diary_repository.dart';
import '../bloc/diary/diary_bloc.dart';
import '../bloc/diary/diary_event.dart';
import '../bloc/diary/diary_state.dart';

class EditPinnedIndicatorsPage extends StatefulWidget {
  final int patientId;
  final List<PinnedParameter> currentPinnedParameters;

  const EditPinnedIndicatorsPage({
    super.key,
    required this.patientId,
    required this.currentPinnedParameters,
  });
  static const String routeName = '/edit-pinned-indicators';

  @override
  State<EditPinnedIndicatorsPage> createState() =>
      _EditPinnedIndicatorsPageState();
}

class _EditPinnedIndicatorsPageState
    extends State<EditPinnedIndicatorsPage> {
  final Map<String, int> _intervalMinutes = {};
  final Set<String> _selectedIndicators = {};
  bool _isLoading = false;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    // Инициализируем текущие показатели и их интервалы
    for (final param in widget.currentPinnedParameters) {
      _selectedIndicators.add(_keyToIndicator(param.key));
      _intervalMinutes[param.key] = param.intervalMinutes < 1 ? 60 : param.intervalMinutes;
    }
    // Имитация начальной загрузки для smoother UX
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    });
  }

  /// Преобразовать ключ API в название индикатора
  String _keyToIndicator(String key) {
    final Map<String, String> mapping = {
      'temperature': 'Температура',
      'blood_pressure': 'Артериальное давление',
      'respiratory_rate': 'Частота дыхания',
      'pain_level': 'Уровень боли',
      'oxygen_saturation': 'Сатурация',
      'blood_sugar': 'Уровень сахара в крови',
      'walk': 'Прогулка',
      'cognitive_games': 'Когнитивные игры',
      'diaper_change': 'Смена подгузников',
      'hygiene': 'Гигиена',
      'skin_moisturizing': 'Увлажнение кожи',
      'meal': 'Прием пищи',
      'medication': 'Прием лекарств',
      'vitamins': 'Прием витаминов',
      'sleep': 'Сон',
      'urine': 'Выпито/выделено и цвет мочи',
      'defecation': 'Дефекация',
      'nausea': 'Тошнота',
      'dyspnea': 'Одышка',
      'cough': 'Кашель',
      'hiccup': 'Икота',
      'vomiting': 'Рвота',
      'itching': 'Зуд',
      'dry_mouth': 'Сухость во рту',
      'taste_disorder': 'Нарушение вкуса',
    };
    return mapping[key] ?? key;
  }

  /// Преобразовать название индикатора в ключ API
  String _indicatorToKey(String indicator) {
    final Map<String, String> mapping = {
      'Температура': 'temperature',
      'Артериальное давление': 'blood_pressure',
      'Частота дыхания': 'respiratory_rate',
      'Уровень боли': 'pain_level',
      'Сатурация': 'oxygen_saturation',
      'Уровень сахара в крови': 'blood_sugar',
      'Прогулка': 'walk',
      'Когнитивные игры': 'cognitive_games',
      'Смена подгузников': 'diaper_change',
      'Гигиена': 'hygiene',
      'Увлажнение кожи': 'skin_moisturizing',
      'Прием пищи': 'meal',
      'Прием лекарств': 'medication',
      'Прием витаминов': 'vitamins',
      'Сон': 'sleep',
      'Выпито/выделено и цвет мочи': 'urine',
      'Дефекация': 'defecation',
      'Тошнота': 'nausea',
      'Одышка': 'dyspnea',
      'Кашель': 'cough',
      'Икота': 'hiccup',
      'Рвота': 'vomiting',
      'Зуд': 'itching',
      'Сухость во рту': 'dry_mouth',
      'Нарушение вкуса': 'taste_disorder',
    };
    return mapping[indicator] ?? indicator.toLowerCase().replaceAll(' ', '_');
  }

  void _openPinnedIndicatorsDialog() {
    showDialog(
      context: context,
      builder: (context) => _IndicatorsSelectionDialog(
        title: 'Выбор показателей (закрепленных)',
        description:
            'Чтобы закрепить параметры которые важно не забывать отслеживать - нажмите на него и нажмите на кнопку выбрать, доступно не более 3 параметров',
        maxSelection: 3,
        selectedIndicators: _selectedIndicators,
        blockedIndicators: null,
        onSelectionChanged: (selected) {
          setState(() {
            _selectedIndicators.clear();
            _selectedIndicators.addAll(selected);
            // Удаляем интервалы для удаленных показателей
            final keysToRemove = <String>[];
            for (final key in _intervalMinutes.keys) {
              if (!selected.contains(_keyToIndicator(key))) {
                keysToRemove.add(key);
              }
            }
            for (final key in keysToRemove) {
              _intervalMinutes.remove(key);
            }
            // Добавляем интервалы по умолчанию для новых показателей
            for (final indicator in selected) {
              final key = _indicatorToKey(indicator);
              if (!_intervalMinutes.containsKey(key)) {
                _intervalMinutes[key] = 60; // По умолчанию каждый час
              }
            }
          });
        },
      ),
    );
  }

  void _savePinnedParameters(BuildContext blocContext) {
    if (_selectedIndicators.isEmpty) {
      toastification.show(
        context: context,
        type: ToastificationType.warning,
        style: ToastificationStyle.fillColored,
        title: const Text('Предупреждение'),
        description: const Text('Выберите хотя бы один показатель'),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }

    // Преобразуем выбранные индикаторы в PinnedParameter
    final pinnedParameters = _selectedIndicators.map((indicator) {
      final key = _indicatorToKey(indicator);
      final intervalMinutes = _intervalMinutes[key] ?? 60;
      return PinnedParameter(
        key: key,
        intervalMinutes: intervalMinutes < 1 ? 60 : intervalMinutes, // Минимум 1 минута
      );
    }).toList();

    setState(() => _isLoading = true);

    // Сохраняем через BLoC
    blocContext.read<DiaryBloc>().add(
          SavePinnedParameters(
            patientId: widget.patientId,
            pinnedParameters: pinnedParameters,
          ),
        );
  }

  void _handleDiaryState(BuildContext context, DiaryState state) {
    if (state is DiaryParametersUpdated) {
      setState(() => _isLoading = false);
      toastification.show(
        context: context,
        type: ToastificationType.success,
        style: ToastificationStyle.fillColored,
        title: const Text('Успешно'),
        description: const Text('Закрепленные показатели обновлены'),
        autoCloseDuration: const Duration(seconds: 2),
      );
      // Возвращаемся назад
      context.pop();
    } else if (state is DiaryError) {
      setState(() => _isLoading = false);
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        title: const Text('Ошибка'),
        description: Text(state.message),
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }

  String _formatInterval(int minutes) {
    if (minutes < 60) {
      return 'каждые $minutes мин';
    } else if (minutes == 60) {
      return 'каждый час';
    } else if (minutes < 1440) {
      final hours = minutes ~/ 60;
      return 'каждые $hours ч';
    } else {
      final days = minutes ~/ 1440;
      return 'каждые $days дн';
    }
  }

  Widget _buildShimmerContent() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info box shimmer
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 16),
          // Pinned indicators section shimmer
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          // Intervals section shimmer
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DiaryBloc(),
      child: BlocListener<DiaryBloc, DiaryState>(
        listener: _handleDiaryState,
        child: Scaffold(
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
              'Редактирование показателей',
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
                    child: _isInitialLoading
                        ? _buildShimmerContent()
                        : Column(
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
                                  'Для закрепленных показателей лучше выбирать показатели, которые нужно замерять через определенный промежуток времени: давление, пульс, температура и др.',
                                  style: GoogleFonts.firaSans(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Pinned indicators section
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
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
                                      'Выберите до 3-х показателей для быстрого доступа с таймером заполнения',
                                      style: GoogleFonts.firaSans(
                                        fontSize: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      onPressed: _openPinnedIndicatorsDialog,
                                      child: Text(
                                        'Выбрать (${_selectedIndicators.length}/3)',
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
                              const SizedBox(height: 16),

                              // Selected indicators with intervals
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Настройка интервалов',
                                      style: GoogleFonts.firaSans(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.grey.shade900,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Настройте интервалы для выбранных показателей',
                                      style: GoogleFonts.firaSans(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    if (_selectedIndicators.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      ..._selectedIndicators.map((indicator) {
                                        final key = _indicatorToKey(indicator);
                                        final currentInterval =
                                            _intervalMinutes[key] ?? 60;

                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      indicator,
                                                      style: GoogleFonts.firaSans(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.grey.shade900,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.close),
                                                    color: Colors.grey.shade600,
                                                    onPressed: () {
                                                      setState(() {
                                                        _selectedIndicators
                                                            .remove(indicator);
                                                        _intervalMinutes.remove(key);
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      'Интервал (минуты):',
                                                      style: GoogleFonts.firaSans(
                                                        fontSize: 14,
                                                        color: Colors.grey.shade700,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  SizedBox(
                                                    width: 100,
                                                    child: TextField(
                                                      keyboardType:
                                                          TextInputType.number,
                                                      decoration: InputDecoration(
                                                        filled: true,
                                                        fillColor: Colors.white,
                                                        border: OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(8),
                                                          borderSide: BorderSide(
                                                              color:
                                                                  Colors.grey.shade300),
                                                        ),
                                                        contentPadding:
                                                            const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 10,
                                                        ),
                                                      ),
                                                      style: GoogleFonts.firaSans(),
                                                      controller: TextEditingController(
                                                        text: currentInterval.toString(),
                                                      )..selection =
                                                          TextSelection.fromPosition(
                                                        TextPosition(
                                                            offset: currentInterval
                                                                .toString()
                                                                .length),
                                                      ),
                                                      onChanged: (value) {
                                                        final newInterval =
                                                            int.tryParse(value) ??
                                                                currentInterval;
                                                        setState(() {
                                                          _intervalMinutes[key] =
                                                              newInterval;
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Текущий интервал: ${_formatInterval(currentInterval)}',
                                                style: GoogleFonts.firaSans(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ] else ...[
                                      const SizedBox(height: 16),
                                      Text(
                                        'Выберите показатели выше, чтобы настроить интервалы',
                                        style: GoogleFonts.firaSans(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                // Save button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: Builder(
                      builder: (blocContext) {
                        return InkWell(
                          onTap: _isLoading
                              ? null
                              : () => _savePinnedParameters(blocContext),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _isLoading
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
                            child: _isLoading
                                ? const Center(
                                    child: SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    'Сохранить',
                                    textAlign: TextAlign.center,
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Импортируем диалог из select_indicators_page
class _IndicatorsSelectionDialog extends StatefulWidget {
  final String title;
  final String description;
  final int? maxSelection;
  final Set<String> selectedIndicators;
  final Set<String>? blockedIndicators;
  final Function(Set<String>) onSelectionChanged;

  const _IndicatorsSelectionDialog({
    required this.title,
    required this.description,
    this.maxSelection,
    required this.selectedIndicators,
    this.blockedIndicators,
    required this.onSelectionChanged,
  });

  @override
  State<_IndicatorsSelectionDialog> createState() =>
      _IndicatorsSelectionDialogState();
}

class _IndicatorsSelectionDialogState
    extends State<_IndicatorsSelectionDialog> {
  late Set<String> _selectedIndicators;

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

  @override
  void dispose() {
    _careCustomController.dispose();
    _physicalCustomController.dispose();
    _excretionCustomController.dispose();
    _symptomCustomController.dispose();
    super.dispose();
  }

  final List<String> _careIndicators = [
    'Прогулка',
    'Когнитивные игры',
    'Смена подгузников',
    'Гигиена',
    'Увлажнение кожи',
    'Прием пищи',
    'Прием лекарств',
    'Прием витаминов',
    'Сон',
  ];

  final List<String> _physicalIndicators = [
    'Температура',
    'Артериальное давление',
    'Частота дыхания',
    'Уровень боли',
    'Сатурация',
    'Уровень сахара в крови',
  ];

  final List<String> _excretionIndicators = [
    'Выпито/выделено и цвет мочи',
    'Дефекация',
  ];

  final List<String> _symptomIndicators = [
    'Тошнота',
    'Одышка',
    'Кашель',
    'Икота',
    'Рвота',
    'Зуд',
    'Сухость во рту',
    'Нарушение вкуса',
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndicators = Set.from(widget.selectedIndicators);
  }

  void _toggleIndicator(String indicator) {
    setState(() {
      if (_selectedIndicators.contains(indicator)) {
        _selectedIndicators.remove(indicator);
      } else {
        if (widget.maxSelection != null &&
            _selectedIndicators.length >= widget.maxSelection!) {
          // Показываем модальное окно с предупреждением
          _showMaxSelectionDialog();
          return;
        }
        _selectedIndicators.add(indicator);
      }
    });
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
                'Можно выбрать не более ${widget.maxSelection} показателей. Снимите выбор с одного из выбранных показателей, чтобы выбрать другой.',
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

  void _confirmSelection() {
    widget.onSelectionChanged(_selectedIndicators);
    Navigator.of(context).pop();
  }

  void _addCustomIndicator(
    TextEditingController controller,
    Set<String> customSet,
  ) {
    if (controller.text.trim().isNotEmpty) {
      final indicator = controller.text.trim();
      if (widget.maxSelection != null &&
          _selectedIndicators.length >= widget.maxSelection! &&
          !_selectedIndicators.contains(indicator)) {
        // Показываем модальное окно при попытке добавить кастомный показатель после достижения лимита
        _showMaxSelectionDialog();
        return;
      }
      setState(() {
        _selectedIndicators.add(indicator);
        customSet.add(indicator);
        controller.clear();
      });
    }
  }

  void _removeCustomIndicator(String indicator, Set<String> customSet) {
    setState(() {
      _selectedIndicators.remove(indicator);
      customSet.remove(indicator);
    });
  }

  Widget _buildIndicatorSection(
    String title,
    List<String> indicators,
    TextEditingController customController,
    Set<String> customIndicators,
  ) {
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
          itemCount: indicators.length,
          itemBuilder: (context, index) {
            final indicator = indicators[index];
            final isSelected = _selectedIndicators.contains(indicator);
            final isBlocked =
                widget.blockedIndicators != null &&
                widget.blockedIndicators!.contains(indicator);
            final isMaxReached =
                widget.maxSelection != null &&
                _selectedIndicators.length >= widget.maxSelection! &&
                !isSelected;
            final isDisabled = isBlocked || isMaxReached;

            return InkWell(
              onTap: isBlocked
                  ? null // Заблокированные показатели не кликабельны
                  : () {
                      if (isMaxReached) {
                        // Показываем модальное окно при попытке выбрать после достижения лимита
                        _showMaxSelectionDialog();
                      } else {
                        _toggleIndicator(indicator);
                      }
                    },
              child: Opacity(
                opacity: isDisabled ? 0.4 : 1.0,
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
                      width: 1.5, // Увеличенная толщина границы
                    ),
                  ),
                  child: Center(
                    child: Text(
                      indicator,
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
        // Показываем кастомные показатели этой категории
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
                      width: 1.5, // Увеличенная толщина границы
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
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 2,
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
                onFieldSubmitted: (_) =>
                    _addCustomIndicator(customController, customIndicators),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                _addCustomIndicator(customController, customIndicators);
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

  @override
  Widget build(BuildContext context) {
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
                      _careIndicators,
                      _careCustomController,
                      _customCareIndicators,
                    ),
                    _buildIndicatorSection(
                      'Физические показатели',
                      _physicalIndicators,
                      _physicalCustomController,
                      _customPhysicalIndicators,
                    ),
                    _buildIndicatorSection(
                      'Выделение мочи и кала',
                      _excretionIndicators,
                      _excretionCustomController,
                      _customExcretionIndicators,
                    ),
                    _buildIndicatorSection(
                      'Тягостные симптомы',
                      _symptomIndicators,
                      _symptomCustomController,
                      _customSymptomIndicators,
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
                  onPressed: _confirmSelection,
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
    );
  }
}
