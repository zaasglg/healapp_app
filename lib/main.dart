import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config/app_config.dart';
import 'router/app_router.dart';
import 'bloc/auth/auth_bloc.dart';
import 'bloc/auth/auth_event.dart';
import 'bloc/organization/organization_bloc.dart';
import 'core/network/api_client.dart';

void main() {
  // Настройка callback для обработки 401 ошибок
  apiClient.setOnUnauthorizedCallback(() {
    // Очистка токена при 401 ошибке
    // Навигация будет обработана через BLoC
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => AuthBloc()..add(const AuthCheckStatus()),
        ),
        BlocProvider(create: (context) => OrganizationBloc()),
      ],
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
    );
  }
}
