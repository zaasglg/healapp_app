import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:toastification/toastification.dart';
import '../config/app_config.dart';
import '../config/hint_ids.dart';
import '../utils/app_icons.dart';
import '../utils/performance_utils.dart';
import '../bloc/hint/hint_bloc.dart';
import '../bloc/hint/hint_event.dart';
import '../bloc/patient/patient_bloc.dart';
import '../bloc/patient/patient_event.dart';
import '../bloc/patient/patient_state.dart';
import '../repositories/patient_repository.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';

class WardsPage extends StatelessWidget {
  const WardsPage({super.key});
  static const String routeName = '/wards';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PatientBloc()..add(const LoadPatients()),
      child: const _WardsPageContent(),
    );
  }
}

class _WardsPageContent extends StatefulWidget {
  const _WardsPageContent();

  @override
  State<_WardsPageContent> createState() => _WardsPageContentState();
}

class _WardsPageContentState extends State<_WardsPageContent> {
  Patient? _createdPatientForDiaryHint;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HintBloc>().add(
        const HintShowRequested(HintIds.wardsAddCard),
      );
    });
  }

  Future<void> _createNewCard(BuildContext context) async {
    _dismissHintIfVisible();

    final result = await context.push('/new-ward-card');
    if (result is Patient && context.mounted) {
      setState(() {
        _createdPatientForDiaryHint = result;
      });
      context.read<PatientBloc>().add(const RefreshPatients());
    }
  }

  void _clearCreatedDiaryHint() {
    _createdPatientForDiaryHint = null;
  }

  void _openDiaryCreation() {
    _clearCreatedDiaryHint();
    context.go('/diaries?showCreateDiaryHint=1');
  }

  void _dismissHintIfVisible() {
    if (context.read<HintBloc>().state.isHintVisible(HintIds.wardsAddCard)) {
      context.read<HintBloc>().add(
        const HintDismissRequested(HintIds.wardsAddCard),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PatientBloc, PatientState>(
      listener: (context, state) {
        if (state is PatientError) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            style: ToastificationStyle.fillColored,
            title: const Text('Ошибка'),
            description: Text(state.message),
            alignment: Alignment.topCenter,
            autoCloseDuration: const Duration(seconds: 4),
            borderRadius: BorderRadius.circular(12),
          );
        } else if (state is PatientDeleted) {
          toastification.show(
            context: context,
            type: ToastificationType.success,
            style: ToastificationStyle.fillColored,
            title: const Text('Успешно'),
            description: const Text('Карточка удалена'),
            alignment: Alignment.topCenter,
            autoCloseDuration: const Duration(seconds: 3),
            borderRadius: BorderRadius.circular(12),
          );
        }
      },
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
                'Карточки подопечных',
                style: GoogleFonts.firaSans(
                  color: Colors.grey.shade900,
                  fontWeight: FontWeight.w700,
                ),
              ),
              centerTitle: true,
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: BlocBuilder<PatientBloc, PatientState>(
                      buildWhen: (previous, current) {
                        return previous.runtimeType != current.runtimeType ||
                            (previous is PatientLoaded &&
                                current is PatientLoaded &&
                                previous.patients.length !=
                                    current.patients.length);
                      },
                      builder: (context, state) {
                        return RefreshIndicator(
                          onRefresh: () async {
                            context.read<PatientBloc>().add(
                              const RefreshPatients(),
                            );
                            await Future.delayed(
                              const Duration(milliseconds: 500),
                            );
                          },
                          color: AppConfig.primaryColor,
                          child: _buildContent(context, state),
                        );
                      },
                    ),
                  ),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, authState) {
                      bool canCreateCard = true;
                      if (authState is AuthAuthenticated) {
                        if (authState.user.accountType == 'doctor' ||
                            authState.user.accountType == 'caregiver') {
                          canCreateCard = false;
                        }
                      }

                      if (!canCreateCard) {
                        return const SizedBox.shrink();
                      }

                      if (_createdPatientForDiaryHint != null) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: double.infinity,
                            child: InkWell(
                              onTap: () => _createNewCard(context),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppConfig.primaryColor,
                                      AppConfig.primaryColor.withValues(
                                        alpha: 0.8,
                                      ),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: Text(
                                  '+ Добавить карточку',
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
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: InkWell(
                            onTap: () => _createNewCard(context),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppConfig.primaryColor,
                                    AppConfig.primaryColor.withValues(
                                      alpha: 0.8,
                                    ),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Text(
                                '+ Добавить карточку',
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
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_createdPatientForDiaryHint != null)
            Positioned.fill(
              child: _CreatedCardDiaryOverlay(
                onCreateDiary: () {
                  final patient = _createdPatientForDiaryHint;
                  if (patient == null) return;
                  _openDiaryCreation();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, PatientState state) {
    if (state is PatientLoading) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: 4,
        itemBuilder: (context, index) => const _ShimmerPatientCard(),
      );
    }

    if (state is PatientError) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Не удалось загрузить данные',
                    style: GoogleFonts.firaSans(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<PatientBloc>().add(
                        const LoadPatients(forceRefresh: true),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.primaryColor,
                    ),
                    child: const Text(
                      'Повторить',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (state is PatientLoaded) {
      final patients = state.patients;

      if (patients.isEmpty) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Для доступа к дневнику подопечного, сначала заполните карточку подопечного по кнопке ниже',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.firaSans(
                      fontSize: 16,
                      color: Colors.grey.shade500,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }

      return OptimizedListView(
        itemCount: patients.length,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        physics: const AlwaysScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          final patient = patients[index];
          return OptimizedWidget(child: _PatientCard(patient: patient));
        },
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [SizedBox.shrink()],
    );
  }
}

class _WardsAddCardHintTooltip extends StatelessWidget {
  const _WardsAddCardHintTooltip();

  @override
  Widget build(BuildContext context) {
    const step = 1;
    const totalSteps = 3;

    final tooltipWidth = (MediaQuery.sizeOf(context).width - 32).clamp(
      280.0,
      430.0,
    );

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: tooltipWidth,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF65ADB8), Color(0xFF1C7D90)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ваш прогресс\nв освоении сервиса',
                style: GoogleFonts.firaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFD6E0E2),
                  height: 1.15,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Шаг $step из $totalSteps',
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFFD6E0E2),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Text(
                'Нажмите ниже, чтобы добавить\n'
                'близкого и начать наблюдение',
                textAlign: TextAlign.center,
                style: GoogleFonts.firaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFD6E0E2),
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

class _CreatedCardDiaryHintTooltip extends StatelessWidget {
  const _CreatedCardDiaryHintTooltip({required this.onCreateDiary});

  final VoidCallback onCreateDiary;

  @override
  Widget build(BuildContext context) {
    final tooltipWidth = (MediaQuery.sizeOf(context).width - 32).clamp(
      280.0,
      430.0,
    );

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: tooltipWidth,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF65ADB8), Color(0xFF1C7D90)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ваш прогресс\nв освоении сервиса',
                style: GoogleFonts.firaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFD6E0E2),
                  height: 1.15,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Шаг 2 из 3',
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFD6E0E2),
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Карточка создана.\nТеперь создайте дневник\n'
                'здоровья, чтобы\nотслеживать состояние',
                textAlign: TextAlign.center,
                style: GoogleFonts.firaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFD6E0E2),
                  height: 1.18,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1C7D90),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: onCreateDiary,
                  child: Text(
                    'Создать дневник',
                    style: GoogleFonts.firaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
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

class _CreatedCardDiaryOverlay extends StatelessWidget {
  const _CreatedCardDiaryOverlay({required this.onCreateDiary});

  final VoidCallback onCreateDiary;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.58),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _CreatedCardDiaryHintTooltip(onCreateDiary: onCreateDiary),
          ),
        ),
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  final Patient patient;

  const _PatientCard({required this.patient});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              context.push('/edit-ward-card', extra: patient);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.fullName,
                          style: GoogleFonts.firaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (patient.age != null) ...[
                              Text(
                                '${patient.age} лет',
                                style: GoogleFonts.firaSans(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Image.asset(
                    AppIcons.chevron_right,
                    width: 20,
                    height: 20,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerPatientCard extends StatelessWidget {
  const _ShimmerPatientCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 150,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 80,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
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
