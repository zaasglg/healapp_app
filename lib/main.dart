import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:toastification/toastification.dart';
import 'config/app_config.dart';
import 'router/app_router.dart';
import 'bloc/auth/auth_bloc.dart';
import 'bloc/auth/auth_event.dart';
import 'bloc/auth/auth_state.dart';
import 'bloc/organization/organization_bloc.dart';
import 'bloc/organization/organization_event.dart';
import 'bloc/employee/employee_bloc.dart';
import 'bloc/hint/hint_bloc.dart';
import 'core/network/api_client.dart';
import 'package:healapp_mobile/core/logging/app_logger.dart';
import 'core/logging/log_config.dart';
import 'services/notification_service.dart';
import 'services/deep_link_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация логирования
  final environment = kDebugMode
      ? Environment.development
      : Environment.production;
  LogConfig.setEnvironment(environment);
  log.info('App starting in ${environment.name} mode', context: LogContext.ui);

  // Инициализация сервиса уведомлений
  await NotificationService().initialize();

  // Инициализация сервиса deep links
  final deepLinkService = DeepLinkService();
  await deepLinkService.initialize();

  // Обработчик приглашений — сохраняем токены для передачи в MyApp
  String? pendingInviteToken;
  String? pendingDiaryInviteToken;
  deepLinkService.onInviteReceived = (token) {
    log.i('Получен токен приглашения: $token');
    pendingInviteToken = token;
  };
  deepLinkService.onDiaryInviteReceived = (token) {
    log.i('Получен токен приглашения дневника: $token');
    pendingDiaryInviteToken = token;
  };

  runApp(
    MyApp(
      pendingInviteToken: pendingInviteToken,
      pendingDiaryInviteToken: pendingDiaryInviteToken,
    ),
  );
}

class MyApp extends StatefulWidget {
  final String? pendingInviteToken;
  final String? pendingDiaryInviteToken;

  const MyApp({
    super.key,
    this.pendingInviteToken,
    this.pendingDiaryInviteToken,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthBloc _authBloc;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc();

    // Подключаем 401-callback: при истечении сессии — автологаут через BLoC
    apiClient.setOnUnauthorizedCallback(() {
      if (_authBloc.state is AuthAuthenticated) {
        log.w('401 от сервера — инициируем автологаут');
        _authBloc.add(const AuthSessionExpired());
      }
    });

    // Для Web: проверяем токен в URL для авто-логина
    if (kIsWeb) {
      _handleWebToken();
    } else {
      _authBloc.add(const AuthCheckStatus());
    }

    // Обрабатываем pending invite token после инициализации роутера
    if (widget.pendingInviteToken != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appRouter.go('/invite/${widget.pendingInviteToken}');
      });
    } else if (widget.pendingDiaryInviteToken != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appRouter.go('/diary-invite/${widget.pendingDiaryInviteToken}');
      });
    }
  }

  void _handleWebToken() {
    try {
      final uri = Uri.base;
      log.i('🔍 Uri.base при запуске: $uri');

      String? token = uri.queryParameters['token'];

      if ((token == null || token.isEmpty) &&
          uri.toString().contains('token=')) {
        log.w('⚠️ Токен не найден в queryParameters, пробуем regex...');
        final match = RegExp(r'[?&]token=([^&#]+)').firstMatch(uri.toString());
        if (match != null) {
          token = Uri.decodeComponent(match.group(1)!);
          log.i('✅ Токен найден через regex: $token');
        }
      } else if (token != null) {
        log.i('✅ Токен найден в queryParameters: $token');
      }

      if (token != null && token.isNotEmpty) {
        log.i('📍 Web: Запуск авторизации по токену...');
        _authBloc.add(AuthLoginWithToken(token));
      } else {
        log.d('❌ Токен не найден — стандартная проверка статуса');
        _authBloc.add(const AuthCheckStatus());
      }
    } catch (e) {
      log.e('🔥 Ошибка при получении токена из URL: $e');
      _authBloc.add(const AuthCheckStatus());
    }
  }

  @override
  void dispose() {
    apiClient.setOnUnauthorizedCallback(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        BlocProvider(create: (context) => HintBloc()),
        BlocProvider(
          create: (context) =>
              OrganizationBloc()..add(const LoadOrganizationRequested()),
        ),
        BlocProvider(create: (context) => EmployeeBloc()),
      ],
      child: ToastificationWrapper(
        child: MaterialApp.router(
          title: 'Здраво - дневник здоровья',
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
