import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:toastification/toastification.dart';
import 'config/app_config.dart';
import 'router/app_router.dart';
import 'bloc/auth/auth_bloc.dart';
import 'bloc/auth/auth_event.dart';
import 'bloc/organization/organization_bloc.dart';
import 'bloc/organization/organization_event.dart';
import 'bloc/employee/employee_bloc.dart';
import 'core/network/api_client.dart';
import 'services/notification_service.dart';
import 'services/deep_link_service.dart';
import 'utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация сервиса уведомлений
  await NotificationService().initialize();

  // Инициализация сервиса deep links
  final deepLinkService = DeepLinkService();
  await deepLinkService.initialize();

  // Обработчик приглашений
  String? pendingInviteToken;
  deepLinkService.onInviteReceived = (token) {
    log.i('Получен токен приглашения: $token');
    pendingInviteToken = token;
    // Пытаемся навигировать с задержкой для готовности роутера
    _navigateToInvite(token);
  };

  // Настройка callback для обработки 401 ошибок
  apiClient.setOnUnauthorizedCallback(() {
    // Очистка токена при 401 ошибке
    // Навигация будет обработана через BLoC
  });

  runApp(MyApp(pendingInviteToken: pendingInviteToken));
}

/// Функция для безопасной навигации к invite странице
void _navigateToInvite(String token) {
  // Пытаемся навигировать с задержкой и повторными попытками
  Future.delayed(const Duration(milliseconds: 500), () {
    _tryNavigateToInvite(token, attempt: 1);
  });
}

void _tryNavigateToInvite(String token, {int attempt = 1, int maxAttempts = 5}) {
  try {
    appRouter.go('/invite/$token');
    log.i('Успешная навигация к invite странице');
  } catch (e) {
    log.w('Попытка $attempt: Ошибка навигации к invite: $e');
    if (attempt < maxAttempts) {
      // Повторная попытка с увеличивающейся задержкой
      Future.delayed(Duration(milliseconds: 300 * attempt), () {
        _tryNavigateToInvite(token, attempt: attempt + 1, maxAttempts: maxAttempts);
      });
    } else {
      log.e('Не удалось навигировать к invite после $maxAttempts попыток');
    }
  }
}

class MyApp extends StatefulWidget {
  final String? pendingInviteToken;
  
  const MyApp({super.key, this.pendingInviteToken});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Обрабатываем pending invite token после инициализации приложения
    if (widget.pendingInviteToken != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          try {
            appRouter.go('/invite/${widget.pendingInviteToken}');
          } catch (e) {
            log.e('Ошибка навигации к invite: $e');
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => AuthBloc()..add(const AuthCheckStatus()),
        ),
        BlocProvider(
          create: (context) =>
              OrganizationBloc()..add(const LoadOrganizationRequested()),
        ),
        BlocProvider(create: (context) => EmployeeBloc()),
      ],
      child: ToastificationWrapper(
        child: MaterialApp.router(
          title: 'HealApp',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          routerConfig: appRouter,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ru', 'RU'), Locale('en', 'US')],
          locale: const Locale('ru', 'RU'),
        ),
      ),
    );
  }
}
