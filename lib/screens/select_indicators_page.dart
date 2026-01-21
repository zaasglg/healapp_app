import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:toastification/toastification.dart';
import '../config/app_config.dart';
import '../utils/app_icons.dart';
import '../repositories/patient_repository.dart';
import '../repositories/diary_repository.dart';
import '../utils/health_diary/indicator_utils.dart';
import '../bloc/diary/diary_bloc.dart';
import '../bloc/diary/diary_event.dart';
import '../bloc/diary/diary_state.dart';

class SelectIndicatorsPage extends StatefulWidget {
  final Patient? patient;

  const SelectIndicatorsPage({super.key, this.patient});
  static const String routeName = '/select-indicators';

  @override
  State<SelectIndicatorsPage> createState() => _SelectIndicatorsPageState();
}

class _SelectIndicatorsPageState extends State<SelectIndicatorsPage> {
  static const Map<String, String> _indicatorKeyMap = {
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

  final Set<String> _pinnedIndicators = {};
  final Set<String> _allIndicators = {};
  final List<String> _systemCustomIndicators = [];
  final DiaryRepository _diaryRepository = DiaryRepository();
  bool _isLoading = false;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    // Убрана искусственная задержка для быстрой загрузки
    _isInitialLoading = false;
    _loadSystemCustomIndicators();
  }

  Patient? get _patient => widget.patient;

  void _openPinnedIndicatorsDialog() {
    showDialog(
      context: context,
      builder: (context) => _IndicatorsSelectionDialog(
        title: 'Выбор показателей (закрепленных)',
        description:
            'Чтобы закрепить параметры которые важно не забывать отслеживать - нажмите на него и нажмите на кнопку выбрать, доступно не более 3 параметров',
        maxSelection: 3,
        selectedIndicators: _pinnedIndicators,
        systemIndicators: _systemCustomIndicators,
        onSelectionChanged: (selected) {
          setState(() {
            _pinnedIndicators.clear();
            _pinnedIndicators.addAll(selected);
          });
        },
      ),
    );
  }

  void _openAllIndicatorsDialog() {
    showDialog(
      context: context,
      builder: (context) => _IndicatorsSelectionDialog(
        title: 'Выбор показателей',
        description:
            'Чтобы выбрать индивидуальные параметры которые важно отслеживать - нажмите на него и после выбора всех необходимых нажмите на кнопку выбрать',
        maxSelection: null,
        selectedIndicators: _allIndicators,
        blockedIndicators:
            _pinnedIndicators, // Блокируем показатели, выбранные в закрепленных
        systemIndicators: _systemCustomIndicators,
        onSelectionChanged: (selected) {
          setState(() {
            _allIndicators.clear();
            _allIndicators.addAll(selected);
          });
        },
      ),
    );
  }

  /// Преобразовать название индикатора в ключ API
  String _indicatorToKey(String indicator) {
    return _indicatorKeyMap[indicator] ??
        indicator.toLowerCase().replaceAll(' ', '_');
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

  Future<void> _loadSystemCustomIndicators() async {
    if (_patient == null) return;

    try {
      final diary = await _diaryRepository.getDiaryByPatientId(_patient!.id);
      if (diary == null) return;

      final indicatorKeys = _normalizeIndicatorKeys(
        diary.settings?['all_indicators'] ?? diary.settings?['allIndicators'],
      );
      if (indicatorKeys.isEmpty) return;

      final baseKeys = _indicatorKeyMap.values.toSet();
      final customKeys = indicatorKeys
          .where((key) => !baseKeys.contains(key))
          .toSet();

      if (customKeys.isEmpty) return;

      final labels = customKeys
          .map(getIndicatorLabel)
          .where((label) => label.isNotEmpty)
          .toSet()
          .toList();

      if (labels.isEmpty) return;

      if (mounted) {
        setState(() {
          _systemCustomIndicators
            ..clear()
            ..addAll(labels);
        });
      }
    } catch (_) {}
  }

  void _createDiary(BuildContext blocContext) {
    if (_patient == null) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        title: const Text('Ошибка'),
        description: const Text('Пациент не выбран'),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }

    // Проверяем, что выбран хотя бы один индикатор
    if (_pinnedIndicators.isEmpty && _allIndicators.isEmpty) {
      toastification.show(
        context: context,
        type: ToastificationType.warning,
        style: ToastificationStyle.fillColored,
        title: const Text('Внимание'),
        description: const Text(
          'Выберите хотя бы один показатель для дневника',
        ),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }

    // Логируем patient_id
    debugPrint(
      '🔍 Создание дневника для пациента: ${_patient!.fullName}, ID: ${_patient!.id}',
    );
    debugPrint('📌 Закрепленные индикаторы: $_pinnedIndicators');
    debugPrint('📋 Все индикаторы: $_allIndicators');

    // Преобразуем выбранные индикаторы в PinnedParameter
    final pinnedParameters = _pinnedIndicators.map((indicator) {
      return PinnedParameter(
        key: _indicatorToKey(indicator),
        intervalMinutes: 60, // По умолчанию каждый час
      );
    }).toList();

    // Формируем settings: объединяем все индикаторы (закрепленные + остальные)
    final allIndicatorKeys = {
      ..._pinnedIndicators.map(_indicatorToKey),
      ..._allIndicators.map(_indicatorToKey),
    }.toList();

    setState(() => _isLoading = true);

    // Устанавливаем таймаут для безопасности (15 секунд)
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        debugPrint('⏱️ Таймаут создания дневника (15 сек)');
        setState(() => _isLoading = false);
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Таймаут'),
          description: const Text(
            'Сервер не отвечает. Проверьте интернет-соединение и попробуйте снова',
          ),
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    });

    // Создаём дневник через BLoC
    blocContext.read<DiaryBloc>().add(
      CreateDiary(
        patientId: _patient!.id,
        pinnedParameters: pinnedParameters,
        settings: allIndicatorKeys.isNotEmpty
            ? {'all_indicators': allIndicatorKeys}
            : null,
      ),
    );
  }

  void _handleDiaryState(BuildContext context, DiaryState state) {
    debugPrint('🔔 Получено состояние: ${state.runtimeType}');

    if (state is DiaryLoading) {
      debugPrint('⏳ Загрузка...');
      // Убедимся, что состояние загрузки установлено
      if (!_isLoading) {
        setState(() => _isLoading = true);
      }
    } else if (state is DiaryCreatedState) {
      setState(() => _isLoading = false);
      debugPrint(
        '✅ Дневник создан: ID=${state.diary.id}, patientId=${state.diary.patientId}',
      );
      toastification.show(
        context: context,
        type: ToastificationType.success,
        style: ToastificationStyle.fillColored,
        title: const Text('Успешно'),
        description: const Text('Дневник здоровья создан'),
        autoCloseDuration: const Duration(seconds: 2),
      );
      // Переходим на страницу дневника с правильными параметрами
      context.pushReplacement(
        '/health-diary/${state.diary.id}/${state.diary.patientId}',
      );
    } else if (state is DiaryConflict) {
      setState(() => _isLoading = false);
      debugPrint(
        '⚠️ Конфликт: дневник уже существует (ID=${state.existingDiaryId})',
      );
      toastification.show(
        context: context,
        type: ToastificationType.warning,
        style: ToastificationStyle.fillColored,
        title: const Text('Дневник существует'),
        description: Text(state.message),
        autoCloseDuration: const Duration(seconds: 3),
      );
      // Переходим на страницу существующего дневника
      // Используем existingDiaryId и patientId из _patient
      if (_patient != null) {
        context.pushReplacement(
          '/health-diary/${state.existingDiaryId}/${_patient!.id}',
        );
      } else {
        debugPrint(
          '❌ Ошибка: пациент не определен при переходе к существующему дневнику',
        );
      }
    } else if (state is DiaryError) {
      setState(() => _isLoading = false);
      debugPrint('❌ Ошибка создания дневника: ${state.message}');
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        title: const Text('Ошибка'),
        description: Text(state.message),
        autoCloseDuration: const Duration(seconds: 3),
      );
    } else if (state is DiaryInitial || state is DiariesLoaded) {
      // Сбрасываем загрузку для любого другого состояния
      if (_isLoading) {
        debugPrint('🔄 Сброс состояния загрузки для ${state.runtimeType}');
        setState(() => _isLoading = false);
      }
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
          // All indicators section shimmer
          Container(
            height: 160,
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
              'Выберите показатели',
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
                                        'Выбрать (${_pinnedIndicators.length}/3)',
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

                              // All indicators section
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
                                      'Все показатели',
                                      style: GoogleFonts.firaSans(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.grey.shade900,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Выберите остальные показатели для отслеживания',
                                      style: GoogleFonts.firaSans(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: AppConfig.primaryColor,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onPressed: _openAllIndicatorsDialog,
                                      child: Text(
                                        'Выбрать (${_allIndicators.length})',
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
                // Create diary button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: Builder(
                      builder: (blocContext) {
                        return InkWell(
                          onTap: _isLoading
                              ? null
                              : () => _createDiary(blocContext),
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
                                    'Создать дневник',
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

class _IndicatorsSelectionDialog extends StatefulWidget {
  final String title;
  final String description;
  final int? maxSelection;
  final Set<String> selectedIndicators;
  final Set<String>?
  blockedIndicators; // Заблокированные показатели (из закрепленных)
  final List<String> systemIndicators;
  final Function(Set<String>) onSelectionChanged;

  const _IndicatorsSelectionDialog({
    required this.title,
    required this.description,
    this.maxSelection,
    required this.selectedIndicators,
    this.blockedIndicators,
    this.systemIndicators = const [],
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
  final TextEditingController _systemCustomController = TextEditingController();

  // Кастомные показатели для каждой категории
  final Set<String> _customCareIndicators = {};
  final Set<String> _customPhysicalIndicators = {};
  final Set<String> _customExcretionIndicators = {};
  final Set<String> _customSymptomIndicators = {};
  final Set<String> _customSystemIndicators = {};

  @override
  void dispose() {
    _careCustomController.dispose();
    _physicalCustomController.dispose();
    _excretionCustomController.dispose();
    _symptomCustomController.dispose();
    _systemCustomController.dispose();
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
                    if (widget.systemIndicators.isNotEmpty) ...[
                      _buildIndicatorSection(
                        'Дополнительные показатели',
                        widget.systemIndicators,
                        _systemCustomController,
                        _customSystemIndicators,
                      ),
                    ],
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
