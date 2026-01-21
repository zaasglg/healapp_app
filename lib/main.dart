import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

void _tryNavigateToInvite(
  String token, {
  int attempt = 1,
  int maxAttempts = 5,
}) {
  try {
    appRouter.go('/invite/$token');
    log.i('Успешная навигация к invite странице');
  } catch (e) {
    log.w('Попытка $attempt: Ошибка навигации к invite: $e');
    if (attempt < maxAttempts) {
      // Повторная попытка с увеличивающейся задержкой
      Future.delayed(Duration(milliseconds: 300 * attempt), () {
        _tryNavigateToInvite(
          token,
          attempt: attempt + 1,
          maxAttempts: maxAttempts,
        );
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
          create: (context) {
            final authBloc = AuthBloc();

            // Для Web версии: проверяем наличие токена в URL для авто-логина
            if (kIsWeb) {
              try {
                // Uri.base содержит полный текущий URL в момент запуска
                final uri = Uri.base;
                log.i('🔍 Uri.base при запуске: $uri');
                log.d('🔍 Uri.base.queryParameters: ${uri.queryParameters}');

                String? token = uri.queryParameters['token'];

                // Fallback: если в queryParameters пусто (из-за особенностей хэш-роутинга),
                // пробуем распарсить строку URL вручную
                if ((token == null || token.isEmpty) &&
                    uri.toString().contains('token=')) {
                  log.w(
                    '⚠️ Токен не найден в queryParameters, пробуем regex...',
                  );
                  // Ищем token=... до следующего амперсанда или конца строки или решетки
                  final match = RegExp(
                    r'[?&]token=([^&#]+)',
                  ).firstMatch(uri.toString());
                  if (match != null) {
                    final rawToken = match.group(1)!;
                    // Декодируем (например, %7C -> |)
                    token = Uri.decodeComponent(rawToken);
                    log.i('✅ Токен найден через regex: $token');
                  }
                } else if (token != null) {
                  log.i('✅ Токен найден в queryParameters: $token');
                }

                if (token != null && token.isNotEmpty) {
                  log.i('📍 Web: Запуск авторизации по токену...');
                  authBloc.add(AuthLoginWithToken(token));
                  return authBloc;
                } else {
                  log.d('❌ Токен не найден ни одним способом');
                }
              } catch (e) {
                log.e('🔥 Ошибка при получении токена из URL: $e');
              }
            }

            return authBloc..add(const AuthCheckStatus());
          },
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
          builder: (context, child) {
            if (kIsWeb && child != null) {
              return Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: child,
                ),
              );
            }
            return child ?? const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
