import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_page.dart';
import '../screens/auth/register_page.dart';
import '../screens/auth/verify_code_page.dart';
import '../screens/auth/fill_organization_profile_page.dart';
import '../screens/auth/fill_caregiver_profile_page.dart';
import '../screens/home_page.dart';
import '../screens/profile_page.dart';
import '../screens/diaries_page.dart';
import '../screens/settings_page.dart';
import '../screens/employees_page.dart';
import '../screens/wards_page.dart';
import '../screens/new_ward_card_page.dart';
import '../screens/edit_ward_card_page.dart';
import '../screens/clients_page.dart';
import '../screens/select_ward_for_diary_page.dart';
import '../screens/select_indicators_page.dart';
import '../screens/health_diary_page.dart';
import '../screens/invite_registration_page.dart';
import '../screens/edit_pinned_indicators_page.dart';
import '../screens/select_entry_to_edit_page.dart';
import '../screens/edit_diary_entry_page.dart';
import '../repositories/diary_repository.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';
import '../repositories/patient_repository.dart';

/// Конфигурация роутера приложения
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    // Получаем состояние авторизации
    final authBloc = context.read<AuthBloc>();
    final authState = authBloc.state;

    // Если пользователь на splash и авторизован - перенаправляем на профиль
    if (state.matchedLocation == '/splash' && authState is AuthAuthenticated) {
      return '/profile';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/verify-code/:phone',
      name: 'verify-code',
      builder: (context, state) {
        final phone = state.pathParameters['phone'] ?? '';
        return VerifyCodePage(phone: phone);
      },
    ),
    GoRoute(
      path: '/fill-organization-profile',
      name: 'fill-organization-profile',
      builder: (context, state) => const FillOrganizationProfilePage(),
    ),
    GoRoute(
      path: '/fill-caregiver-profile',
      name: 'fill-caregiver-profile',
      builder: (context, state) => const FillCaregiverProfilePage(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const ProfilePage(),
    ),
    GoRoute(
      path: '/diaries',
      name: 'diaries',
      builder: (context, state) => const DiariesPage(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/employees',
      name: 'employees',
      builder: (context, state) => const EmployeesPage(),
    ),
    GoRoute(
      path: '/wards',
      name: 'wards',
      builder: (context, state) => const WardsPage(),
    ),
    GoRoute(
      path: '/new-ward-card',
      name: 'new-ward-card',
      builder: (context, state) => const NewWardCardPage(),
    ),
    GoRoute(
      path: '/edit-ward-card',
      name: 'edit-ward-card',
      builder: (context, state) {
        final patient = state.extra as Patient;
        return EditWardCardPage(patient: patient);
      },
    ),
    GoRoute(
      path: '/clients',
      name: 'clients',
      builder: (context, state) => const ClientsPage(),
    ),
    GoRoute(
      path: '/select-ward-for-diary',
      name: 'select-ward-for-diary',
      builder: (context, state) => const SelectWardForDiaryPage(),
    ),
    GoRoute(
      path: '/select-indicators',
      name: 'select-indicators',
      builder: (context, state) {
        final patient = state.extra as Patient?;
        return SelectIndicatorsPage(patient: patient);
      },
    ),
    GoRoute(
      path: '/edit-pinned-indicators',
      name: 'edit-pinned-indicators',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>;
        return EditPinnedIndicatorsPage(
          patientId: args['patientId'] as int,
          currentPinnedParameters:
              args['pinnedParameters'] as List<PinnedParameter>,
        );
      },
    ),
    GoRoute(
      path: '/select-entry-to-edit',
      name: 'select-entry-to-edit',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
        if (args == null) {
          throw Exception(
            'Missing required arguments for select-entry-to-edit',
          );
        }
        return SelectEntryToEditPage(
          diaryId: args['diaryId'] as int,
          patientId: args['patientId'] as int,
          entries: args['entries'] as List<DiaryEntry>,
          pinnedParameters:
              (args['pinnedParameters'] as List<PinnedParameter>?) ?? [],
          allIndicators: (args['allIndicators'] as List<String>?) ?? [],
        );
      },
    ),
    GoRoute(
      path: '/edit-diary-entry',
      name: 'edit-diary-entry',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
        if (args == null) {
          throw Exception('Missing required arguments for edit-diary-entry');
        }
        return EditDiaryEntryPage(
          entry: args['entry'] as DiaryEntry,
          diaryId: args['diaryId'] as int,
          patientId: args['patientId'] as int,
        );
      },
    ),
    GoRoute(
      path: '/health-diary/:id/:patientId',
      name: 'health-diary',
      builder: (context, state) {
        final diaryId = int.parse(state.pathParameters['id'] ?? '0');
        final patientId = int.parse(state.pathParameters['patientId'] ?? '0');
        return HealthDiaryPage(diaryId: diaryId, patientId: patientId);
      },
    ),
    GoRoute(
      path: '/invite/:token',
      name: 'invite',
      builder: (context, state) {
        final token = state.pathParameters['token'] ?? '';
        return InviteRegistrationPage(token: token);
      },
    ),
  ],
);
