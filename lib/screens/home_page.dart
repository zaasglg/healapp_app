import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_icons.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';
import '../bloc/diary/diary_bloc.dart';
import '../bloc/diary/diary_event.dart';
import '../bloc/diary/diary_state.dart';
import '../bloc/hint/hint_bloc.dart';
import '../bloc/hint/hint_event.dart';
import '../config/hint_ids.dart';
import '../repositories/diary_repository.dart';
import '../models/diary.dart';
import 'health_diary/widgets/modals/measurement_modal.dart';
import 'health_diary/widgets/modals/time_picker_modal.dart';
import 'health_diary/utils/indicator_utils.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late DiaryBloc _diaryBloc;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _diaryBloc = DiaryBloc();
    _diaryBloc.add(const LoadDiaries());
    // Обновляем таймеры каждую минуту
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HintBloc>().add(
        const HintShowRequested(HintIds.homeQuickStart),
      );
    });
  }

  @override
  void dispose() {
    _diaryBloc.close();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.manropeTextTheme(Theme.of(context).textTheme);
    final authState = context.watch<AuthBloc>().state;
    final isCardsHintVisible = context.watch<HintBloc>().state.isHintVisible(HintIds.homeQuickStart);
    final canManageEmployees = _canManageEmployees(authState);

    return BlocProvider.value(
      value: _diaryBloc,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileRow(textTheme: textTheme),
                const SizedBox(height: 92),
                Text(
                  'Здраво',
                  style: GoogleFonts.manrope(
                    textStyle: textTheme.displaySmall,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF4A4E54),
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Забота о Вас — каждый час.',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF4F545A),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 56),
                BlocBuilder<DiaryBloc, DiaryState>(
                  builder: (context, state) {
                    return _PinnedIndicatorsCard(
                      textTheme: textTheme,
                      diaryState: state,
                      onAddTap: () => _showAddPinnedModal(context, state),
                      onParameterTap: (diary, param) =>
                          _showMeasurementForParam(context, diary, param),
                    );
                  },
                ),
                const SizedBox(height: 24),
                _ActionTiles(
                  textTheme: textTheme,
                  onRouteSheetTap: () => _showRouteSheetModal(context),
                  onAlarmTap: () => _showAlarmModal(context),
                  onCardsTap: () {
                    if (isCardsHintVisible) {
                      context.read<HintBloc>().add(
                        const HintDismissRequested(HintIds.homeQuickStart),
                      );
                    }
                    context.push('/wards');
                  },
                  canManageEmployees: canManageEmployees,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _canManageEmployees(AuthState authState) {
    if (authState is! AuthAuthenticated) return true;

    final roles = authState.user.roles ?? const <String>[];
    final hasOwnerOrAdminRole = roles.any(
      (role) => role.toLowerCase() == 'owner' || role.toLowerCase() == 'admin',
    );
    if (hasOwnerOrAdminRole) return true;

    // На части аккаунтов бэкенд может не прислать roles: для них даём доступ
    // по типу организации, чтобы не ломать текущий сценарий владельца.
    final accountType = authState.user.accountType?.toLowerCase();
    return (accountType == 'pansionat' || accountType == 'agency') &&
        roles.isEmpty;
  }

  // ─── Маршрутный лист ───────────────────────────────────────────────────────

  void _showRouteSheetModal(BuildContext context) {
    _showDiaryPickerModal(
      context,
      title: 'Маршрутный лист',
      subtitle: 'Выберите для какого подопечного открыть маршрутный лист',
      targetTabIndex: 3,
    );
  }

  void _showAlarmModal(BuildContext context) {
    _showDiaryPickerModal(
      context,
      title: 'Будильники',
      subtitle: 'Выберите для какого подопечного открыть будильники',
      targetTabIndex: 1,
    );
  }

  void _showDiaryPickerModal(
    BuildContext context, {
    required String title,
    required String subtitle,
    required int targetTabIndex,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: _diaryBloc,
        child: _RouteSheetDiaryPickerModal(
          title: title,
          subtitle: subtitle,
          onDiarySelected: (diary) {
            Navigator.pop(context);
            context.push(
              '/health-diary/${diary.id}/${diary.patientId}?tab=$targetTabIndex',
            );
          },
        ),
      ),
    );
  }

  // ─── Закрепленные показатели ───────────────────────────────────────────────

  void _showAddPinnedModal(BuildContext context, DiaryState state) {
    if (state is DiariesLoaded) {
      if (state.diaries.isEmpty) {
        // Нет дневников — предлагаем создать
        _showNoDiariesDialog(context);
      } else {
        // Есть дневники — выбрать для каких добавить показатели
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _SelectDiaryForPinnedModal(
            diaries: state.diaries,
            onDiarySelected: (diary) {
              Navigator.pop(context);
              context.push(
                '/edit-pinned-indicators',
                extra: {
                  'patientId': diary.patientId,
                  'pinnedParameters': diary.pinnedParameters,
                },
              );
            },
          ),
        );
      }
    } else {
      // Дневники ещё не загружены — переходим на страницу выбора
      context.push('/select-indicators');
    }
  }

  void _showNoDiariesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Нет дневников'),
        content: const Text(
          'Чтобы добавить закрепленные показатели, сначала создайте дневник для подопечного.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/select-ward-for-diary');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3A8FB5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Создать дневник',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Запись показателя ─────────────────────────────────────────────────────

  Future<void> _showMeasurementForParam(
    BuildContext context,
    Diary diary,
    PinnedParameter param,
  ) async {
    final key = param.key;
    final label = param.label;
    final unit = getMeasurementUnit(key);
    final description = getIndicatorDescription(key);
    final messenger = ScaffoldMessenger.of(context);
    final inputType = getIndicatorInputType(key);

    dynamic resultValue;
    String displayText = '';

    // Выбираем модальное окно в зависимости от типа параметра
    if (inputType == IndicatorInputType.boolean) {
      // Булевый параметр — модалка "Было/Не было"
      final result = await _showBooleanModal(
        context: context,
        title: label,
        description: description.isNotEmpty
            ? description
            : 'Отметьте, было ли это',
      );
      if (result != null) {
        resultValue = result;
        displayText = result ? 'Было' : 'Не было';
      }
    } else if (inputType == IndicatorInputType.timeRange) {
      // Диапазон времени — два пикера (начало и конец)
      final result = await _showTimeRangeModal(
        context: context,
        title: label,
        description: description.isNotEmpty ? description : 'Укажите время',
      );
      if (result != null) {
        resultValue = result;
        displayText = '${result['start']} - ${result['end']}';
      }
    } else if (inputType == IndicatorInputType.time) {
      // Одно время — пикер
      final result = await showTimePickerModal(
        context: context,
        title: label,
        description: description.isNotEmpty ? description : 'Укажите время',
      );
      if (result != null) {
        final hours = result.hour.toString().padLeft(2, '0');
        final minutes = result.minute.toString().padLeft(2, '0');
        resultValue = {'hours': result.hour, 'minutes': result.minute};
        displayText = '$hours:$minutes';
      }
    } else {
      // Измерение — стандартная модалка
      final result = await showMeasurementModal(
        context: context,
        title: label,
        description: description.isNotEmpty ? description : 'Введите значение',
        unit: unit,
        key: key,
      );
      if (result != null) {
        resultValue = result.value;
        displayText = result.displayText;
      }
    }

    if (resultValue != null && mounted) {
      _diaryBloc.add(
        CreateMeasurement(
          patientId: diary.patientId,
          type: _getParamType(key),
          key: key,
          value: {'value': resultValue},
          recordedAt: DateTime.now(),
        ),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('$label: $displayText'),
          backgroundColor: const Color(0xFF3A8FB5),
        ),
      );
    }
  }

  /// Модальное окно для булевых параметров (Было/Не было)
  Future<bool?> _showBooleanModal({
    required BuildContext context,
    required String title,
    required String description,
  }) async {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
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
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        'Не было',
                        style: GoogleFonts.firaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade500,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        'Было',
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
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Отмена',
                  style: GoogleFonts.firaSans(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Модальное окно для диапазона времени (начало - конец) с CupertinoTimerPicker
  Future<Map<String, String>?> _showTimeRangeModal({
    required BuildContext context,
    required String title,
    required String description,
  }) async {
    Duration startDuration = Duration(
      hours: TimeOfDay.now().hour,
      minutes: TimeOfDay.now().minute,
    );
    Duration endDuration = Duration(
      hours: TimeOfDay.now().hour,
      minutes: TimeOfDay.now().minute,
    );

    return showDialog<Map<String, String>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.firaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.firaSans(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Начало
                Text(
                  'Начало:',
                  style: GoogleFonts.firaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hm,
                    initialTimerDuration: startDuration,
                    onTimerDurationChanged: (Duration newDuration) {
                      setModalState(() {
                        startDuration = newDuration;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Конец
                Text(
                  'Конец:',
                  style: GoogleFonts.firaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hm,
                    initialTimerDuration: endDuration,
                    onTimerDurationChanged: (Duration newDuration) {
                      setModalState(() {
                        endDuration = newDuration;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
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
                        onPressed: () {
                          final startHours = startDuration.inHours;
                          final startMinutes = startDuration.inMinutes % 60;
                          final endHours = endDuration.inHours;
                          final endMinutes = endDuration.inMinutes % 60;

                          final startStr =
                              '${startHours.toString().padLeft(2, '0')}:${startMinutes.toString().padLeft(2, '0')}';
                          final endStr =
                              '${endHours.toString().padLeft(2, '0')}:${endMinutes.toString().padLeft(2, '0')}';

                          Navigator.pop(ctx, {
                            'start': startStr,
                            'end': endStr,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A8FB5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
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

  String _getParamType(String key) {
    if (measurementParams.contains(key)) return 'measurement';
    if (booleanParams.contains(key)) return 'boolean';
    if (timeRangeParams.contains(key)) return 'time_range';
    if (timeParams.contains(key)) return 'time';
    return 'text';
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        context.go('/profile');
      },
      borderRadius: BorderRadius.circular(22),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE7ECF0), Color(0xFFD9E2EA)],
              ),
            ),
            child: Center(
              child: SvgPicture.asset(AppIcons.profile, width: 44, height: 44),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Профиль',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: const Color(0xFF4B4F55),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedIndicatorsCard extends StatefulWidget {
  const _PinnedIndicatorsCard({
    required this.textTheme,
    required this.diaryState,
    required this.onAddTap,
    required this.onParameterTap,
  });

  final TextTheme textTheme;
  final DiaryState diaryState;
  final VoidCallback onAddTap;
  final void Function(Diary diary, PinnedParameter param) onParameterTap;

  @override
  State<_PinnedIndicatorsCard> createState() => _PinnedIndicatorsCardState();
}

class _PinnedIndicatorsCardState extends State<_PinnedIndicatorsCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = widget.textTheme;
    // Собираем все закрепленные показатели из всех дневников
    final List<({Diary diary, PinnedParameter param})> allPinned = [];
    if (widget.diaryState is DiariesLoaded) {
      for (final diary in (widget.diaryState as DiariesLoaded).diaries) {
        for (final param in diary.pinnedParameters) {
          allPinned.add((diary: diary, param: param));
        }
      }
    }

    if (allPinned.isNotEmpty) {
      return _buildWithPinned(context, allPinned, textTheme);
    }
    return _buildEmpty(context, textTheme);
  }

  Widget _buildEmpty(BuildContext context, TextTheme textTheme) {
    const double iconSize = 90;
    const double cardRadius = 28.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(cardRadius),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              left: 72,
              right: 16,
              top: 18,
              bottom: 18,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFE1F3F3),
              borderRadius: BorderRadius.circular(cardRadius),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Добавьте закрепленные\nпоказатели',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF26344A),
                          height: 1.2,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 38,
                        child: ElevatedButton(
                          onPressed: widget.onAddTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF4A5A6A),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFEBF1F5)),
                            ),
                          ),
                          child: Text(
                            'Добавить',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFE7ECF0), Color(0xFFD9E2EA)],
                        ),
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          AppIcons.profile,
                          width: 44,
                          height: 44,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Близкий',
                      style: textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5E6A78),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: -8,
            bottom: -1,
            child: Image.asset(
              AppIcons.heart,
              width: iconSize,
              height: iconSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithPinned(
    BuildContext context,
    List<({Diary diary, PinnedParameter param})> items,
    TextTheme textTheme,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE1F3F3),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: PageView.builder(
              controller: _pageController,
              itemCount: items.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, i) {
                final item = items[i];
                final param = item.param;
                final diary = item.diary;
                final isOverdue = param.status == PinnedParameterStatus.overdue;
                final patientShortName =
                    diary.patient?.shortName ?? 'Подопечный';

                return ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      // Фон
                      Positioned.fill(
                        child: Container(color: const Color(0xFFE1F3F3)),
                      ),
                      // Иконка сердца — левый нижний угол
                      Positioned(
                        left: -8,
                        bottom: -4,
                        child: Image.asset(
                          AppIcons.heart,
                          width: 90,
                          height: 90,
                        ),
                      ),
                      // Контент
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 72,
                          right: 12,
                          top: 14,
                          bottom: 14,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Текст + кнопка
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isOverdue
                                        ? 'Измерить ${param.label.toLowerCase()}\nПросрочено!'
                                        : 'Измерить ${param.label.toLowerCase()}\nчерез: ${param.timerText.replaceAll('Через ', '')}',
                                    textAlign: TextAlign.center,
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF26344A),
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 34,
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          widget.onParameterTap(diary, param),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(
                                          0xFF4A5A6A,
                                        ),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 28,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          side: const BorderSide(
                                            color: Color(0xFFD8EDEF),
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Записать',
                                        style: textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF3A7A8A),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Аватар подопечного
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFE7ECF0),
                                        Color(0xFFD9E2EA),
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: SvgPicture.asset(
                                      AppIcons.profile,
                                      width: 44,
                                      height: 44,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  patientShortName,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFF5E6A78),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Точки-индикаторы
          if (items.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(items.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentPage == i ? 16 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? const Color(0xFF3A8FB5)
                          : const Color(0xFFB0CDD5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionTiles extends StatelessWidget {
  const _ActionTiles({
    required this.textTheme,
    required this.onRouteSheetTap,
    required this.onAlarmTap,
    required this.onCardsTap,
    required this.canManageEmployees,
  });

  final TextTheme textTheme;
  final VoidCallback onRouteSheetTap;
  final VoidCallback onAlarmTap;
  final VoidCallback onCardsTap;
  final bool canManageEmployees;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _BlueTile(
                title: canManageEmployees ? 'Сотрудники' : 'Маршрутный\nлист',
                showArrow: true,
                onTap: canManageEmployees
                    ? () => context.push('/employees')
                    : onRouteSheetTap,
                textTheme: textTheme,
                icon: AppIcons.doctor,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: InkWell(
                onTap: () => context.push('/diaries'),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: SizedBox(
                    height: 100,
                    child: Image.asset(
                      "assets/icons/diary_block.png",
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _BlueTile(
                title: 'Карточки',
                showArrow: true,
                onTap: onCardsTap,
                textTheme: textTheme,
                icon: AppIcons.cart,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: InkWell(
                onTap: canManageEmployees ? onRouteSheetTap : onAlarmTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: SizedBox(
                    height: 100,
                    child: Image.asset(
                      canManageEmployees
                          ? "assets/icons/calendar_block.png"
                          : "assets/icons/clock_block.png",
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BlueTile extends StatelessWidget {
  const _BlueTile({
    required this.title,
    required this.onTap,
    required this.textTheme,
    this.showArrow = false,
    this.icon,
  });

  final String title;
  final VoidCallback onTap;
  final TextTheme textTheme;
  final bool showArrow;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF61B4C6), Color(0xFF317799)],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Иконка — левый нижний угол
              if (icon == AppIcons.doctor)
                Positioned(
                  left: -23,
                  bottom: -5,
                  child: Image.asset(icon!, width: 110, height: 110),
                ),
              if (icon == AppIcons.cart)
                Positioned(
                  left: -23,
                  bottom: -13,
                  child: Image.asset(icon!, width: 110, height: 110),
                ),
              if (icon == AppIcons.calendar)
                Positioned(
                  left: -20,
                  bottom: -10,
                  child: Image.asset(icon!, width: 102, height: 102),
                ),

              // Текст и стрелка — правый центр
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.firaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            height: 1,
                          ),
                        ),
                      ),
                      if (showArrow)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Image.asset(
                            AppIcons.chevron_right,
                            width: 21,
                            height: 21,
                            color: Colors.white,
                          ),
                        ),
                    ],
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

// ─── Модальное окно выбора дневника для маршрутного листа ─────────────────────

class _RouteSheetDiaryPickerModal extends StatefulWidget {
  const _RouteSheetDiaryPickerModal({
    required this.title,
    required this.subtitle,
    required this.onDiarySelected,
  });

  final String title;
  final String subtitle;
  final void Function(Diary diary) onDiarySelected;

  @override
  State<_RouteSheetDiaryPickerModal> createState() =>
      _RouteSheetDiaryPickerModalState();
}

class _RouteSheetDiaryPickerModalState
    extends State<_RouteSheetDiaryPickerModal> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.manropeTextTheme(Theme.of(context).textTheme);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF26344A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF7A8A9A),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Поиск подопечного...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF4F5F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          BlocBuilder<DiaryBloc, DiaryState>(
            builder: (context, state) {
              if (state is DiaryLoading) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                );
              }
              if (state is DiariesLoaded) {
                final query = _searchController.text.toLowerCase();
                final diaries = state.diaries.where((d) {
                  if (query.isEmpty) return true;
                  final name = d.patient?.fullName ?? '';
                  return name.toLowerCase().contains(query);
                }).toList();

                if (diaries.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Дневники не найдены',
                      style: textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                  );
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: diaries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final diary = diaries[i];
                      final name = diary.patient?.fullName ?? 'Подопечный';
                      return ListTile(
                        onTap: () => widget.onDiarySelected(diary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        tileColor: const Color(0xFFF4F5F7),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFE7ECF0), Color(0xFFD9E2EA)],
                            ),
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              AppIcons.profile,
                              width: 40,
                              height: 40,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF3A8FB5),
                        ),
                      );
                    },
                  ),
                );
              }
              return const SizedBox(height: 32);
            },
          ),
        ],
      ),
    );
  }
}

// ─── Модальное окно выбора дневника для закрепленных показателей ──────────────

class _SelectDiaryForPinnedModal extends StatefulWidget {
  const _SelectDiaryForPinnedModal({
    required this.diaries,
    required this.onDiarySelected,
  });

  final List<Diary> diaries;
  final void Function(Diary diary) onDiarySelected;

  @override
  State<_SelectDiaryForPinnedModal> createState() =>
      _SelectDiaryForPinnedModalState();
}

class _SelectDiaryForPinnedModalState
    extends State<_SelectDiaryForPinnedModal> {
  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.manropeTextTheme(Theme.of(context).textTheme);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Выберите дневник',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF26344A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Для какого подопечного добавить закрепленные показатели?',
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF7A8A9A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: widget.diaries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final diary = widget.diaries[i];
                final name = diary.patient?.fullName ?? 'Подопечный';
                final hasPinned = diary.pinnedParameters.isNotEmpty;
                return ListTile(
                  onTap: () => widget.onDiarySelected(diary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  tileColor: const Color(0xFFF4F5F7),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFE7ECF0), Color(0xFFD9E2EA)],
                      ),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        AppIcons.profile,
                        width: 40,
                        height: 40,
                      ),
                    ),
                  ),
                  title: Text(
                    name,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: hasPinned
                      ? Text(
                          '${diary.pinnedParameters.length} показателей',
                          style: textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF3A8FB5),
                          ),
                        )
                      : Text(
                          'Нет закрепленных',
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF3A8FB5),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
