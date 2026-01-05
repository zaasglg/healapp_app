import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_config.dart';
import '../utils/app_icons.dart';
import '../bloc/patient/patient_bloc.dart';
import '../bloc/patient/patient_event.dart';
import '../bloc/patient/patient_state.dart';
import '../repositories/patient_repository.dart';
import '../bloc/organization/organization_bloc.dart';
import '../bloc/organization/organization_state.dart';
import '../bloc/diary/diary_bloc.dart';
import '../bloc/diary/diary_event.dart';
import '../bloc/diary/diary_state.dart';

class SelectWardForDiaryPage extends StatefulWidget {
  const SelectWardForDiaryPage({super.key});
  static const String routeName = '/select-ward-for-diary';

  @override
  State<SelectWardForDiaryPage> createState() => _SelectWardForDiaryPageState();
}

class _SelectWardForDiaryPageState extends State<SelectWardForDiaryPage> {
  void _selectWard(Patient patient) {
    context.push('/select-indicators', extra: patient);
  }

  /// Форматирование даты рождения
  String _formatBirthDate(DateTime? date) {
    if (date == null) return 'Не указана';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Info box shimmer
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),
            // Patient card shimmers
            ...List.generate(
              4,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => PatientBloc()..add(const LoadPatients()),
        ),
        BlocProvider(
          create: (context) => DiaryBloc()..add(const LoadDiaries()),
        ),
      ],
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
            'Выберите карточку подопечного',
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
                child: BlocBuilder<PatientBloc, PatientState>(
                  builder: (context, state) {
                    if (state is PatientLoading) {
                      return _buildShimmerList();
                    }

                    if (state is PatientError) {
                      return Center(
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
                              'Ошибка загрузки',
                              style: GoogleFonts.firaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              state.message,
                              style: GoogleFonts.firaSans(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                context.read<PatientBloc>().add(
                                  const LoadPatients(),
                                );
                              },
                              child: Text(
                                'Повторить',
                                style: GoogleFonts.firaSans(
                                  color: AppConfig.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (state is PatientLoaded) {
                      var patients = state.patients;

                      // Фильтруем пациентов по организации
                      final orgState = context.watch<OrganizationBloc>().state;
                      if (orgState is OrganizationLoaded) {
                        final orgId = orgState.organization['id'] as int?;
                        if (orgId != null) {
                          patients = patients
                              .where((p) => p.organizationId == orgId)
                              .toList();
                        }
                      }

                      // Получаем список дневников и исключаем пациентов с существующими дневниками
                      final diaryState = context.watch<DiaryBloc>().state;
                      if (diaryState is DiariesLoaded) {
                        final existingPatientIds = diaryState.diaries
                            .map((diary) => diary.patientId)
                            .toSet();

                        patients = patients
                            .where((p) => !existingPatientIds.contains(p.id))
                            .toList();
                      }

                      if (patients.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Нет доступных подопечных',
                                style: GoogleFonts.firaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Для всех подопечных уже созданы дневники',
                                style: GoogleFonts.firaSans(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

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
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
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
                                  color: AppConfig.primaryColor.withOpacity(
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Выберите карточку подопечного, для которого вы хотите создать дневник',
                                  style: GoogleFonts.firaSans(
                                    fontSize: 14,
                                    color: AppConfig.primaryColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Patient cards
                              ...patients.map((patient) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Container(
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
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _selectWard(patient),
                                        borderRadius: BorderRadius.circular(16),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      patient.fullName,
                                                      style:
                                                          GoogleFonts.firaSans(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: Colors
                                                                .grey
                                                                .shade900,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Дата рождения: ${_formatBirthDate(patient.birthDate)}',
                                                      style:
                                                          GoogleFonts.firaSans(
                                                            fontSize: 14,
                                                            color: Colors
                                                                .grey
                                                                .shade600,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Пол: ${patient.genderLabel}',
                                                      style:
                                                          GoogleFonts.firaSans(
                                                            fontSize: 14,
                                                            color: Colors
                                                                .grey
                                                                .shade600,
                                                          ),
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
                              }),
                            ],
                          ),
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),
              // Bottom button
              Builder(
                builder: (blocContext) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: InkWell(
                        onTap: () async {
                          final result = await context.push('/new-ward-card');
                          if (result == true && context.mounted) {
                            blocContext.read<PatientBloc>().add(
                              const RefreshPatients(),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppConfig.primaryColor,
                                AppConfig.primaryColor.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'Создать новую карточку',
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
    );
  }
}
