import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:toastification/toastification.dart';
import '../config/app_config.dart';
import '../utils/app_icons.dart';
import '../utils/performance_utils.dart';
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

class _WardsPageContent extends StatelessWidget {
  const _WardsPageContent();

  Future<void> _createNewCard(BuildContext context) async {
    final result = await context.push('/new-ward-card');
    // Если пациент был создан (result == true), обновляем список
    if (result == true && context.mounted) {
      context.read<PatientBloc>().add(const RefreshPatients());
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
                    // Перестраиваем только при изменении состояния
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
                        await Future.delayed(const Duration(milliseconds: 500));
                      },
                      color: AppConfig.primaryColor,
                      child: _buildContent(context, state),
                    );
                  },
                ),
              ),
              // Bottom button
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, authState) {
                  bool canCreateCard = true;
                  if (authState is AuthAuthenticated) {
                    // 'specialist' corresponds to "Частная сиделка"
                    if (authState.user.accountType == 'specialist') {
                      canCreateCard = false;
                    }
                  }

                  if (!canCreateCard) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: InkWell(
                        onTap: () => _createNewCard(context),
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
              color: Colors.black.withOpacity(0.06),
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

  String _getInitials(Patient patient) {
    final parts = <String>[];
    if (patient.firstName != null && patient.firstName!.isNotEmpty) {
      parts.add(patient.firstName![0].toUpperCase());
    }
    if (patient.lastName != null && patient.lastName!.isNotEmpty) {
      parts.add(patient.lastName![0].toUpperCase());
    }
    return parts.isNotEmpty ? parts.join() : '?';
  }

  Color _getMobilityColor(String? mobility) {
    switch (mobility) {
      case 'walking':
        return Colors.green.shade600;
      case 'wheelchair':
        return Colors.orange.shade600;
      case 'bedridden':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
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
              color: Colors.black.withOpacity(0.06),
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
