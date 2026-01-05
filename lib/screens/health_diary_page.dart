import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:go_router/go_router.dart';
import '../utils/app_logger.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../utils/app_icons.dart';
import '../bloc/route_sheet/route_sheet_cubit.dart';
import '../bloc/route_sheet/route_sheet_state.dart';
import '../bloc/diary/diary_bloc.dart';
import '../bloc/diary/diary_event.dart';
import '../bloc/diary/diary_state.dart';
import '../bloc/organization/organization_bloc.dart';
import '../bloc/organization/organization_state.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';
import '../services/pinned_notification_service.dart';
import '../repositories/diary_repository.dart';
import '../bloc/alarm/alarm_bloc.dart';
import '../bloc/alarm/alarm_event.dart';
import '../repositories/employee_repository.dart';
import '../repositories/invitation_repository.dart';
import '../repositories/organization_repository.dart';
import 'package:toastification/toastification.dart';
import 'health_diary/tabs/alarm_tab.dart';

class HealthDiaryPage extends StatefulWidget {
  final int diaryId;
  final int patientId;

  const HealthDiaryPage({
    super.key,
    required this.diaryId,
    required this.patientId,
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
  bool _isAccessManagementExpanded = false;
  bool _isHistoryDatePickerExpanded = false;
  bool _isRouteSheetDatePickerExpanded = false;
  int? _selectedIndicatorIndex;
  final Map<String, List<String>> _editedTimes = {};

  // Client invitation state
  String? _clientInviteUrl;
  bool _isCreatingInvitation = false;

  // Diary access management state
  final OrganizationRepository _organizationRepository =
      OrganizationRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  List<Map<String, dynamic>> _diaryAccessList = [];
  List<Employee> _allEmployees = [];
  bool _isLoadingAccess = false;

  // Timer for updating display time
  Timer? _displayTimeTimer;

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

  String? _getLastValue(Diary? diary, String key) {
    if (diary == null) return null;
    // Фильтруем записи по ключу
    final entries = diary.entries.where((e) => e.parameterKey == key).toList();
    if (entries.isEmpty) return null;
    // Сортируем по дате (свежие первые)
    entries.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return entries.first.value?.toString();
  }

  Widget _buildIndicatorValueCircle(String? value) {
    return SizedBox(
      width: 90,
      height: 90,
      child: CustomPaint(
        size: const Size(75, 75),
        painter: _DashedCirclePainter(),
        child: Center(
          child: value != null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    value,
                    style: GoogleFonts.firaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                )
              : Container(width: 18, height: 2, color: Colors.white),
        ),
      ),
    );
  }

  int? _animatingFromIndex; // Used during animation
  final Set<String> _selectedPhysicalIndicators = {};
  final Set<String> _selectedExcretionIndicators = {};

  final Map<int, TextEditingController> _measurementControllers = {};
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
  }

  @override
  void dispose() {
    _displayTimeTimer?.cancel();
    _indicatorAnimationController.dispose();
    for (final controller in _measurementControllers.values) {
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

  /// Загрузка списка доступов к дневнику
  Future<void> _loadDiaryAccess() async {
    if (_isLoadingAccess) {
      log.d('_loadDiaryAccess: уже идет загрузка, пропускаем');
      return;
    }

    log.d('=== Начало загрузки списка доступов ===');
    log.d('Diary ID: ${widget.diaryId}');

    setState(() {
      _isLoadingAccess = true;
    });

    try {
      log.d('Запрос getDiaryAccessList...');
      final accessList = await _organizationRepository.getDiaryAccessList(
        diaryId: widget.diaryId,
      );
      log.d('Получен список доступов: ${accessList.length} записей');
      log.d('Access list: $accessList');

      log.d('Запрос getEmployees...');
      final employees = await _employeeRepository.getEmployees();
      log.d('Получен список сотрудников: ${employees.length} записей');

      if (mounted) {
        setState(() {
          _diaryAccessList = accessList;
          _allEmployees = employees;
          _isLoadingAccess = false;
        });
        log.d('Состояние обновлено успешно');
      }
    } catch (e) {
      log.e('=== Ошибка загрузки данных ===');
      log.e('Тип ошибки: ${e.runtimeType}');
      log.e('Сообщение: $e');

      if (mounted) {
        setState(() {
          _isLoadingAccess = false;
        });
      }
    }
  }

  /// Назначение доступа к дневнику
  Future<void> _assignDiaryAccess(Employee employee) async {
    // Используем user_id если есть, иначе id сотрудника
    final userId = employee.userId ?? employee.id;

    log.d('=== Начало назначения доступа ===');
    log.d('Employee ID: ${employee.id}');
    log.d('User ID: ${employee.userId}');
    log.d('Используемый userId: $userId');
    log.d('Patient ID: ${widget.patientId}');
    log.d('Employee name: ${employee.fullName}');

    try {
      log.d('Отправка запроса assignDiaryAccess...');
      await _organizationRepository.assignDiaryAccess(
        patientId: widget.patientId,
        userId: userId,
      );
      log.d('Запрос assignDiaryAccess успешно выполнен');

      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.flat,
          title: Text('Доступ предоставлен'),
          description: Text('${employee.fullName} получил доступ к дневнику'),
          autoCloseDuration: const Duration(seconds: 3),
        );

        log.d('Перезагрузка списка доступов...');
        // Перезагружаем список доступов
        _loadDiaryAccess();
      }
    } catch (e) {
      log.e('=== Ошибка назначения доступа ===');
      log.e('Тип ошибки: ${e.runtimeType}');
      log.e('Сообщение: $e');
      if (e is ApiException) {
        log.e('Status code: ${e.statusCode}');
      }

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
      log.e('Ошибка отзыва доступа: $e');
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
        log.e('Ошибка загрузки сотрудников: $e');
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
                      backgroundColor: AppConfig.primaryColor.withOpacity(0.1),
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
    });
  }

  /// Закрыть раскрытую карточку с анимацией (одновременно)
  void _closeIndicator() {
    final closingIndex = _selectedIndicatorIndex;

    setState(() {
      _animatingFromIndex = closingIndex;
      _selectedIndicatorIndex = null;
    });

    _indicatorAnimationController.reset();
    _indicatorAnimationController.forward().then((_) {
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

    return Container(
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
            secondChild: Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
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
                            ? () => _showIndicatorModal(
                                context,
                                indicatorKey,
                                label,
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
                                color: AppConfig.primaryColor.withOpacity(
                                  isActive ? 0.5 : 0.2,
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
            ),
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
                  onPressed: () => context.go('/diaries'),
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
                  onPressed: () => context.go('/diaries'),
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
              // Определяем количество вкладок в зависимости от роли
              final isOrganizationCaregiver =
                  authState is AuthAuthenticated &&
                  authState.user.hasRole('caregiver');
              final isClientCaregiver =
                  authState is AuthAuthenticated &&
                  authState.user.accountType == 'client' &&
                  authState.user.hasRole('caregiver');
              final isCaregiver = isOrganizationCaregiver || isClientCaregiver;

              // Длина контроллера зависит от роли: 4 для сиделок, 5 для остальных
              final tabLength = isCaregiver ? 4 : 5;

              return DefaultTabController(
                length: tabLength,
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
                      onPressed: () => context.go('/diaries'),
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
                            // Определяем, является ли пользователь сиделкой
                            final isOrganizationCaregiver =
                                authState is AuthAuthenticated &&
                                authState.user.hasRole('caregiver');
                            final isClientCaregiver =
                                authState is AuthAuthenticated &&
                                authState.user.accountType == 'client' &&
                                authState.user.hasRole('caregiver');
                            final isCaregiver =
                                isOrganizationCaregiver || isClientCaregiver;

                            // Формируем список табов динамически
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
                                  unselectedLabelColor: Colors.grey.shade600,
                                  labelStyle: GoogleFonts.firaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  unselectedLabelStyle: GoogleFonts.firaSans(
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
                      // Определяем, является ли пользователь сиделкой
                      final isOrganizationCaregiver =
                          authState is AuthAuthenticated &&
                          authState.user.hasRole('caregiver');
                      final isClientCaregiver =
                          authState is AuthAuthenticated &&
                          authState.user.accountType == 'client' &&
                          authState.user.hasRole('caregiver');
                      final isCaregiver =
                          isOrganizationCaregiver || isClientCaregiver;

                      // Формируем список view динамически
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
                    // Pinned indicators section
                    Text(
                      'Закрепленные показатели',
                      style: GoogleFonts.firaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Show expanded card or horizontal list with smooth simultaneous animation
                    AnimatedBuilder(
                      animation: _indicatorAnimationController,
                      builder: (context, child) {
                        final animValue = _indicatorExpandAnimation.value;
                        final isExpanding = _selectedIndicatorIndex != null;
                        final isClosing =
                            !isExpanding && _animatingFromIndex != null;

                        // Плавные кривые для разных эффектов
                        final fadeCurve = Curves.easeOut;
                        final slideCurve = Curves.easeInOutCubic;
                        final scaleCurve = Curves.easeOutBack;

                        // Вычисляем значения с разными кривыми для более интересной анимации
                        final fadeProgress = fadeCurve.transform(animValue);
                        final slideProgress = slideCurve.transform(animValue);
                        final scaleProgress = scaleCurve.transform(animValue);

                        // During animation, show both states with Stack
                        if (_animatingFromIndex != null ||
                            (isExpanding && animValue < 1.0)) {
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Cards list (fading out and sliding right when expanding, fading in when closing)
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
                                          final param = pinnedParameters[index];
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
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(
                                                          0.06 *
                                                              (1.0 -
                                                                  fadeProgress),
                                                        ),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    _getIndicatorLabel(
                                                      param.key,
                                                    ),
                                                    style: GoogleFonts.firaSans(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  _buildIndicatorValueCircle(
                                                    _getLastValue(
                                                      diary,
                                                      param.key,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Center(
                                                    child: Text(
                                                      _getDisplayTime(
                                                        _editedTimes[param
                                                                .key] ??
                                                            param.times,
                                                      ),
                                                      style: GoogleFonts.firaSans(
                                                        fontSize:
                                                            (_editedTimes[param
                                                                        .key] ??
                                                                    param.times)
                                                                .isEmpty
                                                            ? 10
                                                            : 12,
                                                        color: Colors.white
                                                            .withOpacity(0.9),
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors
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
                                                              color:
                                                                  Colors.white,
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
                              // Expanded card (fading in and expanding from left when expanding, fading out when closing)
                              if (isExpanding || isClosing)
                                Opacity(
                                  opacity: isExpanding
                                      ? fadeProgress.clamp(0.0, 1.0)
                                      : (1.0 - fadeProgress).clamp(0.0, 1.0),
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

                        // Static states (no animation in progress)
                        if (_selectedIndicatorIndex != null) {
                          return _buildExpandedIndicatorCard(
                            context,
                            _selectedIndicatorIndex!,
                            pinnedParameters,
                            diary,
                          );
                        } else if (pinnedParameters.isNotEmpty) {
                          return Row(
                            children: List.generate(pinnedParameters.length, (
                              index,
                            ) {
                              final param = pinnedParameters[index];
                              return Expanded(
                                child: Container(
                                  height: 260,
                                  margin: EdgeInsets.only(
                                    right: index < pinnedParameters.length - 1
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
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
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
                                      const SizedBox(height: 8),
                                      Center(
                                        child: Text(
                                          _getDisplayTime(
                                            _editedTimes[param.key] ??
                                                param.times,
                                          ),
                                          style: GoogleFonts.firaSans(
                                            fontSize:
                                                (_editedTimes[param.key] ??
                                                        param.times)
                                                    .isEmpty
                                                ? 10
                                                : 12,
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
                                            fontWeight: FontWeight.w800,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.grey.shade800,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                            }),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 16),
                    // Test notification button for pinned parameters
                    // All indicators section
                    Text(
                      'Все показатели',
                      style: GoogleFonts.firaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Settings card - shows diary settings (all_indicators)
                    Builder(
                      builder: (context) {
                        // Получаем all_indicators из settings
                        final settings =
                            diary?.settings as Map<String, dynamic>?;
                        final allIndicators =
                            settings?['all_indicators'] as List<dynamic>? ?? [];

                        // Фильтруем показатели по категориям
                        final careIndicators = allIndicators
                            .where(
                              (e) => _careIndicatorKeys.contains(e.toString()),
                            )
                            .toList();
                        final physicalIndicators = allIndicators
                            .where(
                              (e) =>
                                  _physicalIndicatorKeys.contains(e.toString()),
                            )
                            .toList();
                        final excretionIndicators = allIndicators
                            .where(
                              (e) => _excretionIndicatorKeys.contains(
                                e.toString(),
                              ),
                            )
                            .toList();

                        return Column(
                          children: [
                            // Показатели ухода
                            _buildCategoryCard(
                              title: 'Показатели ухода',
                              indicators: careIndicators,
                              fallbackIndicators: _careIndicatorKeys,
                              isExpanded: _isCareExpanded,
                              onToggle: () => setState(
                                () => _isCareExpanded = !_isCareExpanded,
                              ),
                              context: context,
                            ),
                            const SizedBox(height: 12),

                            // Физические показатели
                            _buildCategoryCard(
                              title: 'Физические показатели',
                              indicators: physicalIndicators,
                              fallbackIndicators: _physicalIndicatorKeys,
                              isExpanded: _isPhysicalExpanded,
                              onToggle: () => setState(
                                () =>
                                    _isPhysicalExpanded = !_isPhysicalExpanded,
                              ),
                              context: context,
                            ),
                            const SizedBox(height: 12),

                            // Выделение мочи и кала
                            _buildCategoryCard(
                              title: 'Выделение мочи и кала',
                              indicators: excretionIndicators,
                              fallbackIndicators: _excretionIndicatorKeys,
                              isExpanded: _isExcretionExpanded,
                              onToggle: () => setState(
                                () => _isExcretionExpanded =
                                    !_isExcretionExpanded,
                              ),
                              context: context,
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Кнопки "Изменить показатели" и "Управление доступом" скрыты для сиделок
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, authState) {
                        // Скрываем кнопки только для сиделок (caregiver), но показываем для врачей (doctor)
                        if (authState is AuthAuthenticated &&
                            authState.user.accountType == 'client' &&
                            authState.user.hasRole('caregiver')) {
                          return const SizedBox.shrink();
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
                                  onPressed: () {
                                    if (diary != null &&
                                        diary.entries.isNotEmpty) {
                                      context.push(
                                        '/select-entry-to-edit',
                                        extra: {
                                          'diaryId': widget.diaryId,
                                          'patientId': widget.patientId,
                                          'entries': diary.entries,
                                          'pinnedParameters':
                                              diary.pinnedParameters,
                                        },
                                      );
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
                                                  final status =
                                                      access['status']
                                                          as String? ??
                                                      'active';

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
      'nausea': 'Тошнота',
      'vomiting': 'Рвота',
      'dyspnea': 'Одышка',
      'itching': 'Зуд',
      'cough': 'Кашель',
      'dry_mouth': 'Сухость во рту',
      'hiccup': 'Икота',
      'taste_disorder': 'Нарушение вкуса',
      'care_procedure': 'Процедура ухода',
    };
    return labels[key] ?? key;
  }

  /// Показать модальное окно для заполнения параметра
  void _showIndicatorModal(BuildContext context, String key, String label) {
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

    final textParams = ['feeding', 'cognitive_games'];
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
      _showBooleanModal(context, label, _getIndicatorDescription(key), key);
    } else if (textParams.contains(key)) {
      _showTextModal(
        context,
        label,
        _getIndicatorDescription(key),
        _getIndicatorHint(key),
      );
    } else if (timeRangeParams.contains(key)) {
      _showTimeRangeModal(context, label, _getIndicatorDescription(key));
    } else if (timeParams.contains(key)) {
      _showTimeModal(context, label, _getIndicatorDescription(key));
    } else if (measurementParams.contains(key)) {
      _showMeasurementModal(
        context,
        label,
        _getIndicatorDescription(key),
        _getUnitForParameter(key),
        key,
      );
    } else if (key == 'medication' || key == 'vitamins') {
      _showMedicationModal(context, label, _getIndicatorDescription(key), key);
    } else if (key == 'urine_color') {
      _showUrineColorModal(context, label);
    } else {
      _showMeasurementModal(
        context,
        label,
        _getIndicatorDescription(key),
        _getIndicatorHint(key),
        key,
      );
    }
  }

  String _getIndicatorDescription(String key) {
    const descriptions = {
      'skin_moisturizing': 'Отметьте, было ли увлажнение кожи.',
      'hygiene': 'Отметьте, была ли проведена гигиена.',
      'defecation': 'Отметьте, была ли дефекация.',
      'nausea': 'Отметьте, была ли тошнота.',
      'vomiting': 'Отметьте, была ли рвота.',
      'dyspnea': 'Отметьте, была ли одышка.',
      'itching': 'Отметьте, был ли зуд.',
      'cough': 'Отметьте, был ли кашель.',
      'dry_mouth': 'Отметьте, была ли сухость во рту.',
      'hiccup': 'Отметьте, была ли икота.',
      'taste_disorder': 'Отметьте, было ли нарушение вкуса.',
      'feeding': 'Опишите, что ели и как прошёл приём пищи.',
      'cognitive_games': 'Опишите, какие игры проводились.',
      'walk': 'Укажите время начала и окончания прогулки.',
      'sleep': 'Укажите время отхода ко сну и пробуждения.',
      'diaper_change': 'Укажите время смены подгузника.',
      'blood_pressure': 'Введите показатель артериального давления.',
      'temperature': 'Введите температуру тела.',
      'pulse': 'Введите частоту пульса.',
      'saturation': 'Введите уровень сатурации.',
      'respiratory_rate': 'Введите частоту дыхания.',
      'pain_level': 'Оцените уровень боли от 0 до 10.',
      'sugar_level': 'Введите уровень сахара в крови.',
      'fluid_intake': 'Введите количество выпитой жидкости.',
      'urine_output': 'Введите количество выделенной мочи.',
      'medication': 'Выберите лекарства для приёма.',
      'vitamins': 'Выберите витамины для приёма.',
      'urine_color': 'Выберите цвет мочи.',
    };
    return descriptions[key] ?? '';
  }

  String _getIndicatorHint(String key) {
    const hints = {
      'feeding': 'Например: завтрак — овсянка, чай',
      'cognitive_games': 'Например: шахматы, чтение книги',
    };
    return hints[key] ?? '';
  }

  /// Модальное окно с выбором Было/Не было
  void _showBooleanModal(
    BuildContext context,
    String title,
    String description,
    String key, // Added key
  ) {
    bool? selectedValue;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
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
                            ? () {
                                print('--- Save Boolean Clicked ---');
                                print('Key: $key');
                                print('Value: $selectedValue');

                                context.read<DiaryBloc>().add(
                                  CreateMeasurement(
                                    patientId: widget.patientId,
                                    type: _getParameterType(key),
                                    key: key,
                                    value: selectedValue,
                                    recordedAt: DateTime.now(),
                                  ),
                                );

                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '$title: ${selectedValue! ? "Было" : "Не было"}',
                                    ),
                                    backgroundColor: AppConfig.primaryColor,
                                  ),
                                );
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

  /// Модальное окно с текстовым вводом
  void _showTextModal(
    BuildContext context,
    String title,
    String description,
    String hint,
  ) {
    final controller = TextEditingController();

    showDialog(
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
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: GoogleFonts.firaSans(color: Colors.grey.shade400),
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
                        Navigator.pop(ctx);
                        if (controller.text.isNotEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$title сохранено'),
                              backgroundColor: AppConfig.primaryColor,
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

  /// Модальное окно с выбором времени
  void _showTimeModal(BuildContext context, String title, String description) {
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
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
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: ctx,
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
                            ? () {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '$title: ${selectedTime!.format(ctx)}',
                                    ),
                                    backgroundColor: AppConfig.primaryColor,
                                  ),
                                );
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

  /// Модальное окно с диапазоном времени
  void _showTimeRangeModal(
    BuildContext context,
    String title,
    String description,
  ) {
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
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
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            setModalState(() => startTime = time);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Начало',
                                style: GoogleFonts.firaSans(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                startTime != null
                                    ? startTime!.format(ctx)
                                    : '--:--',
                                style: GoogleFonts.firaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: startTime != null
                                      ? Colors.grey.shade900
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.arrow_forward, color: Colors.grey.shade400),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            setModalState(() => endTime = time);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Окончание',
                                style: GoogleFonts.firaSans(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                endTime != null
                                    ? endTime!.format(ctx)
                                    : '--:--',
                                style: GoogleFonts.firaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: endTime != null
                                      ? Colors.grey.shade900
                                      : Colors.grey.shade400,
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
                        onPressed: startTime != null && endTime != null
                            ? () {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '$title: ${startTime!.format(ctx)} - ${endTime!.format(ctx)}',
                                    ),
                                    backgroundColor: AppConfig.primaryColor,
                                  ),
                                );
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

  /// Модальное окно с вводом измерения
  /// Модальное окно с вводом измерения
  void _showMeasurementModal(
    BuildContext context,
    String title,
    String description,
    String unit,
    String key, // Added key parameter
  ) {
    final controller = TextEditingController();

    showDialog(
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
                        print('--- Save Button Clicked ---');
                        print('Input text: "${controller.text}"');

                        if (controller.text.isNotEmpty) {
                          dynamic value = controller.text;

                          // Parse blood pressure if needed
                          if (key == 'blood_pressure' && value.contains('/')) {
                            final parts = value.split('/');
                            if (parts.length == 2) {
                              value = {
                                'systolic': int.tryParse(parts[0].trim()) ?? 0,
                                'diastolic': int.tryParse(parts[1].trim()) ?? 0,
                              };
                            }
                          }

                          print('Key: $key');
                          print('Processed Value: $value');

                          context.read<DiaryBloc>().add(
                            CreateMeasurement(
                              patientId: widget.patientId,
                              type: _getParameterType(key),
                              key: key,
                              value: value,
                              recordedAt: DateTime.now(),
                            ),
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$title: ${controller.text} $unit'),
                              backgroundColor: AppConfig.primaryColor,
                            ),
                          );
                        }
                        Navigator.pop(ctx);
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

  /// Модальное окно для лекарств/витаминов
  void _showMedicationModal(
    BuildContext context,
    String title,
    String description,
    String key, // Added key
  ) {
    final controller = TextEditingController();

    showDialog(
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
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Введите название',
                  hintStyle: GoogleFonts.firaSans(color: Colors.grey.shade400),
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
                          print('--- Save Medication/Vitamins Clicked ---');
                          print('Key: $key');
                          print('Value: ${controller.text}');

                          context.read<DiaryBloc>().add(
                            CreateMeasurement(
                              patientId: widget.patientId,
                              type: _getParameterType(key),
                              key: key,
                              value: controller.text,
                              recordedAt: DateTime.now(),
                            ),
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$title: ${controller.text}'),
                              backgroundColor: AppConfig.primaryColor,
                            ),
                          );
                        }
                        Navigator.pop(ctx);
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

  /// Модальное окно для выбора цвета мочи
  void _showUrineColorModal(BuildContext context, String title) {
    String? selectedColor;
    final colors = [
      'Светло-жёлтый',
      'Жёлтый',
      'Тёмно-жёлтый',
      'Оранжевый',
      'Красноватый',
      'Коричневый',
    ];

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
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
                  children: colors.map((color) {
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
                            ? () {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$title: $selectedColor'),
                                    backgroundColor: AppConfig.primaryColor,
                                  ),
                                );
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
            color: Colors.black.withOpacity(0.06),
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
                                  : p.intervalMinutes, // Минимум 1 минута
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

                      // 2. Create Measurement
                      if (measurementController.text.isNotEmpty) {
                        dynamic value = measurementController.text;
                        if (param.key == 'blood_pressure' &&
                            value.contains('/')) {
                          final parts = value.split('/');
                          if (parts.length == 2) {
                            value = {
                              'systolic': int.tryParse(parts[0].trim()) ?? 0,
                              'diastolic': int.tryParse(parts[1].trim()) ?? 0,
                            };
                          }
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
                            value: value,
                            notes:
                                null, // User can add notes logic later if needed
                            recordedAt: DateTime.now(),
                          ),
                        );
                        measurementController.clear();
                        hasChanges = true;
                      }

                      if (hasChanges) {
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Measurement Input
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
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
                      SizedBox(
                        height: 44,
                        child: TextFormField(
                          controller: measurementController,
                          style: GoogleFonts.firaSans(
                            fontSize: 14,
                            color: Colors.grey.shade900,
                            height: 1.2,
                          ),
                          textAlignVertical: TextAlignVertical.center,
                          decoration: InputDecoration(
                            hintText: 'Внесите замер',
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
                            ), // Vertical padding ignored due to fixed height + center alignment
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12), // Увеличен отступ
                // Times Logic
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
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
                          final TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: AppConfig.primaryColor,
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                ),
                                child: child!,
                              );
                            },
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
                      // List of times
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
                              height: 44,
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
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              if (timeController.text.length == 5) {
                                setState(() {
                                  final newTimes = List<String>.from(times);
                                  if (!newTimes.contains(timeController.text)) {
                                    newTimes.add(timeController.text);
                                    newTimes.sort();
                                    _editedTimes[param.key] = newTimes;
                                  }
                                });
                                timeController.clear();
                              }
                            },
                            child: Container(
                              width: 32,
                              height: 32,
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

  void _showIndicatorInputDialog(
    BuildContext context,
    String indicatorName,
    String category,
  ) {
    final TextEditingController valueController = TextEditingController();

    // Descriptions for different indicators
    final Map<String, String> descriptions = {
      'Частота дыхания': 'Количество вдохов в минуту.',
      'Температура': 'Температура тела в градусах Цельсия.',
      'Давление': 'Артериальное давление (систолическое/диастолическое).',
      'Пульс': 'Количество ударов сердца в минуту.',
      'Сатурация': 'Насыщение крови кислородом в процентах.',
      'Выпито жидкости': 'Количество выпитой жидкости в миллилитрах.',
      'Выделено мочи': 'Количество выделенной мочи в миллилитрах.',
      'Цвет мочи': 'Описание цвета мочи.',
      'Дефекация': 'Описание дефекации.',
    };

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Text(
                indicatorName,
                textAlign: TextAlign.center,
                style: GoogleFonts.firaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 16),
              // Description 1
              Text(
                descriptions[indicatorName] ?? 'Введите значение показателя.',
                textAlign: TextAlign.center,
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              // Description 2
              Text(
                'Время заполнения фиксируется автоматически',
                textAlign: TextAlign.center,
                style: GoogleFonts.firaSans(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 24),
              // Value label
              Text(
                'Значение',
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 8),
              // Input field
              TextFormField(
                controller: valueController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  color: Colors.grey.shade900,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppConfig.primaryColor,
                      width: 1,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Remove indicator from selection if cancelled
                        setState(() {
                          if (category == 'physical') {
                            _selectedPhysicalIndicators.remove(indicatorName);
                          } else {
                            _selectedExcretionIndicators.remove(indicatorName);
                          }
                        });
                      },
                      child: Text(
                        'Отмена',
                        style: GoogleFonts.firaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        // TODO: Save value
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                        child: Text(
                          'Сохранить',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.firaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
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

  Widget _buildHistoryTab(BuildContext context, Diary? diary) {
    if (diary == null) return const SizedBox();

    // Логируем все записи истории, полученные от API, красиво форматированным JSON
    try {
      final entriesJson = diary.entries.map((e) => e.toJson()).toList();
      final pretty = const JsonEncoder.withIndent('  ').convert(entriesJson);
      log.i('=== Diary history (API) ===\n$pretty');
    } catch (e) {
      log.e('Failed to pretty-print diary entries: $e');
    }

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
                            String displayValue;
                            if (entry.value is Map &&
                                entry.value.containsKey('value')) {
                              displayValue = entry.value['value'].toString();
                            } else {
                              displayValue = entry.value.toString();
                            }

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
                                    ).format(entry.recordedAt),
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
              final isToday =
                  isCurrentMonth &&
                  _selectedDate.year == DateTime.now().year &&
                  _selectedDate.month == DateTime.now().month &&
                  dayNumber == DateTime.now().day;

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
    return _getFormattedEntries(diary).where((entry) {
      return entry.parameterKey != 'medication' &&
          entry.parameterKey != 'vitamins';
    }).toList();
  }

  List<DiaryEntry> _getFormattedEntries(Diary diary) {
    return diary.entries.where((entry) {
      final localRecordedAt = entry.recordedAt.toLocal();
      return localRecordedAt.year == _selectedDate.year &&
          localRecordedAt.month == _selectedDate.month &&
          localRecordedAt.day == _selectedDate.day;
    }).toList()..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
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
    final value = entry.value;

    // Обработка булевых значений
    if (value is bool) {
      return value ? 'Было' : 'Не было';
    }

    // Обработка числовых булевых представлений (1/0)
    if (value is num) {
      if (value == 1) return 'Было';
      if (value == 0) return 'Не было';
    }

    // Обработка Map (например {value: false} или blood_pressure)
    if (value is Map) {
      // Для blood_pressure
      if (entry.parameterKey == 'blood_pressure') {
        final systolic = value['systolic'] ?? value['sys'] ?? 0;
        final diastolic = value['diastolic'] ?? value['dia'] ?? 0;
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
      if (value == '1') return 'Было';
      if (value == '0') return 'Не было';
    }

    // Стандартное отображение с единицами измерения
    String displayValue = value?.toString() ?? '—';
    final unit = _getUnitForParameter(entry.parameterKey);
    if (unit.isNotEmpty && displayValue != '—') {
      displayValue = '$displayValue $unit';
    }

    return displayValue;
  }

  String _getCategoryForParameter(String key) {
    switch (key) {
      case 'bath':
      case 'diaper_change':
      case 'nail_care':
      case 'hair_care':
        return 'Гигиена';
      case 'temperature':
      case 'weight':
      case 'height':
      case 'pulse':
      case 'blood_pressure':
      case 'saturation':
      case 'oxygen_saturation':
      case 'respiratory_rate':
        return 'Физические показатели';
      case 'urine':
      case 'stool':
      case 'vomit':
        return 'Выделения';
      case 'sleep':
      case 'nap':
        return 'Сон';
      case 'feeding':
      case 'breastfeeding':
      case 'bottle':
      case 'solid_food':
        return 'Питание';
      case 'walk':
      case 'activity':
        return 'Активность';
      default:
        return 'Другое';
    }
  }

  Widget _buildValueChip(String value, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppConfig.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.firaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppConfig.primaryColor,
            ),
          ),
          if (unit.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              unit,
              style: GoogleFonts.firaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppConfig.primaryColor.withOpacity(0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getUnitForParameter(String key) {
    switch (key) {
      case 'temperature':
        return '°C';
      case 'weight':
        return 'кг';
      case 'saturation':
      case 'oxygen_saturation':
        return '%';
      case 'blood_sugar':
      case 'sugar_level':
        return 'ммоль/л';
      case 'pulse':
        return 'уд/мин';
      case 'respiratory_rate':
        return 'дв/мин';
      default:
        return '';
    }
  }

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
                          // - сотрудника-си́делки в организации (hasRole('caregiver'))
                          // - пользователя с accountType == 'client' и ролью 'caregiver'
                          final isOrganizationCaregiver =
                              authState is AuthAuthenticated &&
                              authState.user.hasRole('caregiver');

                          final isClientCaregiver =
                              authState is AuthAuthenticated &&
                              authState.user.accountType == 'client' &&
                              authState.user.hasRole('caregiver');

                          // Debug: log current accountType and roles to help diagnose visibility
                          if (authState is AuthAuthenticated) {
                            log.d(
                              'Auth debug (empty-state): accountType=${authState.user.accountType}, roles=${authState.user.roles}',
                            );
                          } else {
                            log.d(
                              'Auth debug (empty-state): not authenticated',
                            );
                          }

                          // Если сиделка в организации ИЛИ клиент с ролью сиделки,
                          // показываем информацию без кнопок
                          if (isOrganizationCaregiver || isClientCaregiver) {
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
          child: RefreshIndicator(
            onRefresh: () async {
              context.read<RouteSheetCubit>().loadRouteSheet();
              await Future.delayed(const Duration(milliseconds: 500));
            },
            color: AppConfig.primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height - 200,
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
                              context.read<RouteSheetCubit>().setSelectedDate(
                                date,
                              );
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
                        margin: const EdgeInsets.symmetric(horizontal: 16),
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
                                final isOrganizationCaregiver =
                                    authState is AuthAuthenticated &&
                                    authState.user.hasRole('caregiver');

                                final isClientCaregiver =
                                    authState is AuthAuthenticated &&
                                    authState.user.accountType == 'client' &&
                                    authState.user.hasRole('caregiver');

                                // Debug: log current accountType and roles to help diagnose visibility
                                if (authState is AuthAuthenticated) {
                                  log.d(
                                    'Auth debug (edit-button): accountType=${authState.user.accountType}, roles=${authState.user.roles}',
                                  );
                                } else {
                                  log.d(
                                    'Auth debug (edit-button): not authenticated',
                                  );
                                }

                                if (isOrganizationCaregiver ||
                                    isClientCaregiver) {
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
              ),
            ),
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

  Widget _buildTaskCard(RouteSheetTask task) {
    Color backgroundColor;
    Color buttonColor;
    String statusText;

    // Check if task is rescheduled first, then apply status colors
    if (task.isRescheduled) {
      backgroundColor = Colors.orange;
      buttonColor = Colors.orange;
      statusText = 'Перенесено';
    } else {
      switch (task.status) {
        case TaskStatus.completed:
          backgroundColor = AppConfig.primaryColor;
          buttonColor = AppConfig.primaryColor;
          statusText = 'Выполнено';
          break;
        case TaskStatus.pending:
          backgroundColor = const Color(0xFF00BCD4);
          buttonColor = const Color(0xFF00BCD4);
          statusText = 'Ожидает';
          break;
        case TaskStatus.cancelled:
          backgroundColor = Colors.orange;
          buttonColor = Colors.orange;
          statusText = 'Отменено';
          break;
        case TaskStatus.missed:
          backgroundColor = Colors.red;
          buttonColor = Colors.red;
          statusText = 'Пропущено';
          break;
      }
    }

    // Определяем, есть ли причина для отображения
    final String? reason = task.comment ?? task.rescheduleReason;
    final bool hasReason =
        reason != null &&
        reason.isNotEmpty &&
        (task.status == TaskStatus.missed ||
            task.status == TaskStatus.cancelled ||
            task.isRescheduled);

    // Высота карточки зависит от наличия причины
    final double cardHeight = hasReason ? 64.0 : 44.0;

    return GestureDetector(
      onTap: () => _showTaskActionsModal(context, task),
      child: Container(
        height: cardHeight,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
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
                      const SizedBox(height: 2),
                      Text(
                        'Причина: $reason',
                        style: GoogleFonts.firaSans(
                          fontSize: 11,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: buttonColor.withOpacity(0.8),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
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
        ),
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
                    // Используем pageContext для следующего диалога
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
    // Сохраняем контекст страницы для snackbar (он остаётся валидным после закрытия диалога)
    final pageContext = context;

    // Определяем тип задачи по relatedDiaryKey или title
    final taskKey = task.relatedDiaryKey ?? _getKeyFromTitle(task.title);

    // Типы показателей
    const booleanParams = [
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
      'diaper_change',
    ];

    const measurementParams = [
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
    ];

    const textParams = [
      'feeding',
      'cognitive_games',
      'meal',
      'medication',
      'vitamins',
    ];

    const timeRangeParams = ['sleep'];

    if (measurementParams.contains(taskKey)) {
      _showMeasurementCompleteDialog(context, task, cubit, taskKey);
    } else if (textParams.contains(taskKey)) {
      _showTextCompleteDialog(context, task, cubit, taskKey);
    } else if (timeRangeParams.contains(taskKey)) {
      _showTimeRangeCompleteDialog(context, task, cubit);
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
      'Температура': 'temperature',
      'Пульс': 'pulse',
      'Сатурация': 'saturation',
      'Частота дыхания': 'respiratory_rate',
      'Смена подгузников': 'diaper_change',
      'Увлажнение кожи': 'skin_moisturizing',
      'Приём лекарств': 'medication',
      'Кормление': 'feeding',
      'Прием пищи': 'meal',
      'Выпито жидкости': 'fluid_intake',
      'Выделено мочи': 'urine_output',
      'Выделение мочи': 'urine',
      'Дефекация': 'defecation',
      'Гигиена': 'hygiene',
      'Когнитивные игры': 'cognitive_games',
      'Приём витаминов': 'vitamins',
      'Сон': 'sleep',
      'Уровень боли': 'pain_level',
      'Уровень сахара': 'blood_sugar',
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
                          comment: 'Было',
                        );
                        // Обновляем дневник локально: создаём запись "Было"
                        try {
                          final key =
                              task.relatedDiaryKey ??
                              _getKeyFromTitle(task.title);
                          final type = _getParameterType(key);
                          context.read<DiaryBloc>().add(
                            CreateMeasurement(
                              patientId: widget.patientId,
                              type: type,
                              key: key,
                              value: true,
                              recordedAt: DateTime.now(),
                            ),
                          );
                        } catch (e) {
                          log.e(
                            'Failed to dispatch diary update after task complete: $e',
                          );
                        }
                        if (pageContext.mounted) {
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
                          comment: 'Не было',
                        );
                        // Обновляем дневник локально: создаём запись "Не было"
                        try {
                          final key =
                              task.relatedDiaryKey ??
                              _getKeyFromTitle(task.title);
                          final type = _getParameterType(key);
                          context.read<DiaryBloc>().add(
                            CreateMeasurement(
                              patientId: widget.patientId,
                              type: type,
                              key: key,
                              value: false,
                              recordedAt: DateTime.now(),
                            ),
                          );
                        } catch (e) {
                          log.e(
                            'Failed to dispatch diary update after task complete: $e',
                          );
                        }
                        if (pageContext.mounted) {
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
                        keyboardType: TextInputType.number,
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
                        keyboardType: TextInputType.number,
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
                          comment: value,
                        );
                        // Обновляем дневник локально: создаём запись с текстовым описанием
                        try {
                          final key =
                              task.relatedDiaryKey ??
                              _getKeyFromTitle(task.title);
                          final type = _getParameterType(key);
                          context.read<DiaryBloc>().add(
                            CreateMeasurement(
                              patientId: widget.patientId,
                              type: type,
                              key: key,
                              value: value,
                              recordedAt: DateTime.now(),
                            ),
                          );
                        } catch (e) {
                          log.e(
                            'Failed to dispatch diary update after text complete: $e',
                          );
                        }
                        // Обновляем дневник локально: создаём запись с измерением
                        try {
                          final key =
                              task.relatedDiaryKey ??
                              _getKeyFromTitle(task.title);
                          dynamic measuredValue = value;
                          if (key == 'blood_pressure' && value.contains('/')) {
                            final parts = value.split('/');
                            if (parts.length >= 2) {
                              final sys = int.tryParse(parts[0].trim()) ?? 0;
                              final dia =
                                  int.tryParse(
                                    parts[1].trim().split(' ').first,
                                  ) ??
                                  0;
                              measuredValue = {
                                'systolic': sys,
                                'diastolic': dia,
                              };
                            }
                          }
                          final type = _getParameterType(key);
                          context.read<DiaryBloc>().add(
                            CreateMeasurement(
                              patientId: widget.patientId,
                              type: type,
                              key: key,
                              value: measuredValue,
                              recordedAt: DateTime.now(),
                            ),
                          );
                        } catch (e) {
                          log.e(
                            'Failed to dispatch diary update after measurement complete: $e',
                          );
                        }
                        if (pageContext.mounted) {
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
                          comment: value,
                        );
                        if (pageContext.mounted) {
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
                          final time = await showTimePicker(
                            context: context,
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
                          final time = await showTimePicker(
                            context: context,
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
                            comment: value,
                          );
                          // Обновляем дневник локально: создаём запись для диапазона времени
                          try {
                            final key =
                                task.relatedDiaryKey ??
                                _getKeyFromTitle(task.title);
                            final type = _getParameterType(key);
                            context.read<DiaryBloc>().add(
                              CreateMeasurement(
                                patientId: widget.patientId,
                                type: type,
                                key: key,
                                value: value,
                                recordedAt: DateTime.now(),
                              ),
                            );
                          } catch (e) {
                            log.e(
                              'Failed to dispatch diary update after time-range complete: $e',
                            );
                          }
                          if (pageContext.mounted) {
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
                              final time = await showTimePicker(
                                context: context,
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
                              final time = await showTimePicker(
                                context: context,
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
          await Future.delayed(const Duration(milliseconds: 500));
        },
        color: AppConfig.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                        'Пока ссылка не создана. Нажмите кнопку ниже, чтобы сформировать персональную ссылку для клиента.',
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      )
                    else ...[
                      Text(
                        'Ссылка создана. Отправьте её клиенту:',
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
                                      ? 'Создать ссылку'
                                      : 'Создать новую ссылку',
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
            .replaceAll('localhost:3000', 'api.sistemizdorovya.ru')
            .replaceAll(
              'http://localhost:3000',
              'https://api.sistemizdorovya.ru',
            )
            .replaceAll(
              'https://localhost:3000',
              'https://api.sistemizdorovya.ru',
            );

        setState(() {
          _clientInviteUrl = correctedUrl;
          _isCreatingInvitation = false;
        });

        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.fillColored,
          title: const Text('Успешно'),
          description: const Text('Ссылка-приглашение создана'),
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
          e.toString().contains('Unauthorized') || e.toString().contains('403')
              ? 'Недостаточно прав для создания приглашения'
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
                            ].map((item) {
                              final isSelected = selectedManipulations.contains(
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
                                  child: Text(
                                    item,
                                    style: GoogleFonts.firaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? AppConfig.primaryColor
                                          : Colors.grey.shade900,
                                    ),
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
                                // TODO: Add custom indicator
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
                            ].map((item) {
                              final isSelected = selectedManipulations.contains(
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
                                  child: Text(
                                    item,
                                    style: GoogleFonts.firaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? AppConfig.primaryColor
                                          : Colors.grey.shade900,
                                    ),
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
                                // TODO: Add custom indicator
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
    ).then((_) {
      careIndicatorController.dispose();
      physicalIndicatorController.dispose();
    });
  }

  void _showManipulationSettingsModal(
    BuildContext context,
    String manipulationName,
    Function(bool shouldAdd) onSave,
    RouteSheetCubit routeSheetCubit,
  ) {
    final TextEditingController timeFromController = TextEditingController();
    final TextEditingController timeToController = TextEditingController();
    final timeMaskFormatter = MaskTextInputFormatter(
      mask: '##:##',
      filter: {"#": RegExp(r'[0-9]')},
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => _ManipulationSettingsModalContent(
        manipulationName: manipulationName,
        onSave: onSave,
        timeFromController: timeFromController,
        timeToController: timeToController,
        timeMaskFormatter: timeMaskFormatter,
        routeSheetCubit: routeSheetCubit,
      ),
    ).then((_) {
      // Dispose контроллеров только после полного закрытия модалки
      // Задержка нужна, чтобы модалка успела полностью закрыться
      Future.delayed(const Duration(milliseconds: 500), () {
        try {
          timeFromController.dispose();
        } catch (e) {
          // Already disposed or still in use
        }
        try {
          timeToController.dispose();
        } catch (e) {
          // Already disposed or still in use
        }
      });
    });
  }

  Widget _buildAlarmTab(BuildContext context) {
    return AlarmTab(diaryId: widget.diaryId);
  }

  /// Показать тестовое уведомление для закрепленного параметра
  Future<void> _showTestPinnedNotification(
    BuildContext context,
    PinnedParameter parameter,
  ) async {
    try {
      final pinnedNotificationService = PinnedNotificationService();
      await pinnedNotificationService.showTestPinnedParameterNotification(
        patientId: widget.patientId,
        parameter: parameter,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Тестовое уведомление отправлено для ${parameter.label}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      log.e('Ошибка показа тестового уведомления: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка отправки тестового уведомления'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _ManipulationSettingsModalContent extends StatefulWidget {
  final String manipulationName;
  final Function(bool shouldAdd) onSave;
  final TextEditingController timeFromController;
  final TextEditingController timeToController;
  final MaskTextInputFormatter timeMaskFormatter;
  final RouteSheetCubit routeSheetCubit;

  const _ManipulationSettingsModalContent({
    required this.manipulationName,
    required this.onSave,
    required this.timeFromController,
    required this.timeToController,
    required this.timeMaskFormatter,
    required this.routeSheetCubit,
  });

  @override
  State<_ManipulationSettingsModalContent> createState() =>
      _ManipulationSettingsModalContentState();
}

class _ManipulationSettingsModalContentState
    extends State<_ManipulationSettingsModalContent> {
  final Set<int> _selectedDays = {}; // 0-6 где 0=ПН, 6=ВС
  Employee? _selectedEmployee;
  final List<String> selectedTimes = [];
  final TextEditingController timeFromController = TextEditingController();
  final TextEditingController timeToController = TextEditingController();
  final timeMaskFormatter = MaskTextInputFormatter(
    mask: '##:##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  static const _dayLabels = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];
  // API использует 0 = Воскресенье, 1 = Понедельник...
  static const _dayApiValues = [1, 2, 3, 4, 5, 6, 0];

  // Сотрудники
  List<Employee> _employees = [];
  bool _isLoadingEmployees = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final repository = EmployeeRepository();
      final employees = await repository.getEmployees();
      if (mounted) {
        setState(() {
          _employees = employees;
          _isLoadingEmployees = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingEmployees = false;
        });
      }
    }
  }

  void _showEmployeeSelectionDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Выберите сотрудника',
              style: GoogleFonts.firaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoadingEmployees)
              const Center(child: CircularProgressIndicator())
            else if (_employees.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'Нет доступных сотрудников',
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _employees.length,
                  itemBuilder: (context, index) {
                    final employee = _employees[index];
                    final isSelected = _selectedEmployee?.id == employee.id;
                    return ListTile(
                      leading: _buildEmployeeAvatar(employee),
                      title: Text(
                        _getEmployeeDisplayName(employee),
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        employee.roleDisplayName,
                        style: GoogleFonts.firaSans(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle,
                              color: AppConfig.primaryColor,
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedEmployee = employee;
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'owner':
        return Colors.purple;
      case 'admin':
        return Colors.blue;
      case 'doctor':
        return Colors.green;
      case 'caregiver':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Виджет аватара сотрудника для маршрутного листа
  Widget _buildEmployeeAvatar(Employee employee) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: _getRoleColor(employee.role).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: employee.avatarUrl != null && employee.avatarUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                ApiConfig.getFullUrl(employee.avatarUrl!),
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Text(
                      _getEmployeeInitials(employee),
                      style: GoogleFonts.firaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _getRoleColor(employee.role),
                      ),
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1,
                        valueColor: AlwaysStoppedAnimation(
                          _getRoleColor(employee.role),
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          : Center(
              child: Text(
                _getEmployeeInitials(employee),
                style: GoogleFonts.firaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _getRoleColor(employee.role),
                ),
              ),
            ),
    );
  }

  /// Получить отображаемое имя сотрудника
  String _getEmployeeDisplayName(Employee employee) {
    // Если у сотрудника есть имя, используем его
    if (employee.fullName != 'Без имени') {
      return employee.fullName;
    }

    // Для владельца без имени показываем название организации
    if (employee.role == 'owner') {
      try {
        final orgBloc = context.read<OrganizationBloc>();
        final orgState = orgBloc.state;
        if (orgState is OrganizationLoaded) {
          final orgName = (orgState.organization['name'] as String?)?.trim();
          if (orgName != null && orgName.isNotEmpty) {
            return orgName;
          }
        }
      } catch (e) {
        // Если OrganizationBloc недоступен, используем значение по умолчанию
      }

      // Значение по умолчанию для владельца
      return 'Erdaulet Organization';
    }

    return employee.fullName;
  }

  /// Получить инициалы сотрудника с учетом организации
  String _getEmployeeInitials(Employee employee) {
    // Для владельца без имени используем инициалы организации
    if (employee.role == 'owner' && employee.fullName == 'Без имени') {
      // Пытаемся получить название организации из контекста
      try {
        final orgBloc = context.read<OrganizationBloc>();
        final orgState = orgBloc.state;
        if (orgState is OrganizationLoaded) {
          final orgName = (orgState.organization['name'] as String?)?.trim();
          if (orgName != null && orgName.isNotEmpty) {
            // Берем первые буквы слов из названия организации
            final words = orgName.split(' ');
            if (words.length >= 2) {
              return '${words[0][0].toUpperCase()}${words[1][0].toUpperCase()}';
            } else if (words.isNotEmpty) {
              return words[0].length >= 2
                  ? '${words[0][0].toUpperCase()}${words[0][1].toUpperCase()}'
                  : words[0][0].toUpperCase();
            }
          }
        }
      } catch (e) {
        // Если OrganizationBloc недоступен, используем значение по умолчанию
      }

      // Значение по умолчанию для владельца
      return 'EO';
    }

    // Обычная логика для всех остальных
    final first = employee.firstName?.isNotEmpty == true
        ? employee.firstName![0].toUpperCase()
        : '';
    final last = employee.lastName?.isNotEmpty == true
        ? employee.lastName![0].toUpperCase()
        : '';

    if (first.isEmpty && last.isEmpty) {
      return '?';
    }
    return '$last$first';
  }

  @override
  void dispose() {
    timeFromController.dispose();
    timeToController.dispose();
    super.dispose();
  }

  void _addTimeSlot() {
    final timeFrom = timeFromController.text.trim();
    final timeTo = timeToController.text.trim();

    if (timeFrom.isNotEmpty && timeTo.isNotEmpty) {
      setState(() {
        selectedTimes.add('$timeFrom - $timeTo');
        timeFromController.clear();
        timeToController.clear();
      });
    }
  }

  void _removeTimeSlot(int index) {
    setState(() {
      selectedTimes.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
                  'Настройте\nманипуляцию',
                  style: GoogleFonts.firaSans(
                    fontSize: 22,
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
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Manipulation name
                  Text(
                    widget.manipulationName,
                    style: GoogleFonts.firaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Employee selection
                  Text(
                    'Выберите сотрудника:',
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _showEmployeeSelectionDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedEmployee != null
                                    ? AppConfig.primaryColor
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                if (_selectedEmployee != null) ...[
                                  _buildEmployeeAvatar(_selectedEmployee!),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Text(
                                    _selectedEmployee != null
                                        ? _getEmployeeDisplayName(
                                            _selectedEmployee!,
                                          )
                                        : 'Выберите сотрудника',
                                    style: GoogleFonts.firaSans(
                                      fontSize: 14,
                                      color: _selectedEmployee != null
                                          ? Colors.grey.shade900
                                          : Colors.grey.shade500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          // Переход на страницу сотрудников для добавления
                          context.push('/employees');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Добавить',
                          style: GoogleFonts.firaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Date selection
                  Text(
                    'Дни недели:',
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(7, (index) {
                        final isSelected = _selectedDays.contains(index);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedDays.remove(index);
                              } else {
                                _selectedDays.add(index);
                              }
                            });
                          },
                          child: Container(
                            width: 42,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppConfig.primaryColor
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? null
                                  : Border.all(color: Colors.grey.shade300),
                            ),
                            child: Center(
                              child: Text(
                                _dayLabels[index],
                                style: GoogleFonts.firaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Time selection
                  Text(
                    'Выберите время',
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Selected times chips
                  if (selectedTimes.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedTimes.asMap().entries.map((entry) {
                        final index = entry.key;
                        final time = entry.value;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppConfig.primaryColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                time,
                                style: GoogleFonts.firaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _removeTimeSlot(index),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Time input fields
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: timeFromController,
                          inputFormatters: [timeMaskFormatter],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Время с',
                            hintStyle: GoogleFonts.firaSans(
                              fontSize: 14,
                              color: Colors.grey.shade500,
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: timeToController,
                          inputFormatters: [timeMaskFormatter],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Время до',
                            hintStyle: GoogleFonts.firaSans(
                              fontSize: 14,
                              color: Colors.grey.shade500,
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
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _addTimeSlot,
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
                ],
              ),
            ),
          ),
          // Bottom buttons
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
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      // Валидация
                      if (_selectedDays.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Пожалуйста, выберите хотя бы один день',
                              style: GoogleFonts.firaSans(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (selectedTimes.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Пожалуйста, добавьте хотя бы один временной слот',
                              style: GoogleFonts.firaSans(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      try {
                        // Функция для нормализации формата времени (7:00 -> 07:00)
                        String normalizeTime(String time) {
                          final parts = time.trim().split(':');
                          if (parts.length != 2) return time;

                          final hour = parts[0].padLeft(2, '0');
                          final minute = parts[1].padLeft(2, '0');
                          return '$hour:$minute';
                        }

                        // Преобразуем selectedTimes в TimeRange
                        final timeRanges = selectedTimes.map((timeRange) {
                          final parts = timeRange.split(' - ');
                          return TimeRange(
                            start: normalizeTime(parts[0]),
                            end: normalizeTime(
                              parts.length > 1 ? parts[1] : parts[0],
                            ),
                          );
                        }).toList();

                        // Преобразуем выбранные дни в формат API
                        final apiDaysOfWeek = _selectedDays
                            .map((index) => _dayApiValues[index])
                            .toList();

                        // Создаём шаблон задачи через API
                        await widget.routeSheetCubit.createTemplate(
                          title: widget.manipulationName,
                          assignedTo: _selectedEmployee?.id,
                          daysOfWeek: apiDaysOfWeek,
                          timeRanges: timeRanges,
                          startDate: DateTime.now(),
                        );

                        // Перезагружаем список задач
                        await widget.routeSheetCubit.loadRouteSheet();

                        widget.onSave(true);

                        if (context.mounted) {
                          context.pop();

                          // Добавляем небольшую задержку перед показом SnackBar
                          // чтобы избежать конфликтов с навигацией
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Манипуляция успешно добавлена',
                                    style: GoogleFonts.firaSans(),
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          });
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Ошибка при создании манипуляции: $e',
                                style: GoogleFonts.firaSans(),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
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
                      'Сохранить',
                      style: GoogleFonts.firaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Отмена',
                      style: GoogleFonts.firaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for dashed circle
class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    // Draw circle with radial gradient
    final gradient = RadialGradient(
      colors: [
        const Color(0xFFA0E7E5).withOpacity(0.3),
        const Color(0xFF61B4C6).withOpacity(0.2),
      ],
    );
    final circlePaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, circlePaint);

    // Draw dashed outline with rectangular dashes
    final dashPaint = Paint()
      ..color = const Color(0xFFA0E7E5).withOpacity(0.6)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const dashCount = 20;
    const dashAngle = (2 * 3.14159) / dashCount;
    const dashLength =
        dashAngle * 0.4; // 40% of dash angle for dash, 60% for space

    for (int i = 0; i < dashCount; i++) {
      final angle = i * dashAngle;
      final startAngle = angle;
      final endAngle = angle + dashLength;

      final path = Path();
      path.addArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        endAngle - startAngle,
      );
      canvas.drawPath(path, dashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}
