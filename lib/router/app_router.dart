import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_page.dart';
import '../screens/auth/register_page.dart';
import '../screens/auth/verify_code_page.dart';
import '../screens/auth/fill_organization_profile_page.dart';
import '../screens/home_page.dart';
import '../screens/profile_page.dart';
import '../screens/diaries_page.dart';
import '../screens/settings_page.dart';
import '../screens/employees_page.dart';
import '../screens/wards_page.dart';
import '../screens/new_ward_card_page.dart';
import '../screens/clients_page.dart';
import '../screens/select_ward_for_diary_page.dart';
import '../screens/select_indicators_page.dart';
import '../screens/health_diary_page.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';

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
      builder: (context, state) => const SelectIndicatorsPage(),
    ),
    GoRoute(
      path: '/health-diary',
      name: 'health-diary',
      builder: (context, state) => const HealthDiaryPage(),
    ),
  ],
);
