import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_config.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/auth/auth_state.dart';
import '../utils/performance_utils.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  static const String routeName = '/splash';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    // Настройка анимации
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // Запуск анимации
    _animationController.forward();

    // Запускаем проверку авторизации после небольшой задержки для анимации
    _checkAuthStatus();
  }

  void _checkAuthStatus() async {
    // Задержка для показа splash screen
    await Future.delayed(const Duration(seconds: 15));

    if (mounted) {
      // Отправляем событие проверки статуса авторизации
      context.read<AuthBloc>().add(const AuthCheckStatus());
    }
  }

  void _navigateBasedOnAuthState(AuthState state) {
    if (_hasNavigated || !mounted) return;

    // Используем addPostFrameCallback для безопасной навигации после завершения кадра
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasNavigated) return;

      try {
        if (state is AuthAuthenticated) {
          _hasNavigated = true;
          if (mounted) {
            context.go('/diaries');
          }
        } else if (state is AuthUnauthenticated) {
          _hasNavigated = true;
          if (mounted) {
            context.go('/login');
          }
        }
      } catch (e) {
        // Логируем ошибку навигации, но не прерываем выполнение
        debugPrint('Ошибка навигации: $e');
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        _navigateBasedOnAuthState(state);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F8),
        body: SafeArea(
          child: Stack(
            children: [
              // Фоновые декоративные элементы
              _buildBackgroundElements(),

              // Основной контент
              Center(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Логотип с улучшенным дизайном
                            _buildLogo(),
                            const SizedBox(height: 56),

                            // Название приложения с улучшенной типографикой
                            _buildAppTitle(),
                            const SizedBox(height: 10),

                            // Слоган
                            _buildSlogan(),
                            const SizedBox(height: 80),

                            // Индикатор загрузки с улучшенным дизайном
                            _buildLoadingIndicator(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Фоновые декоративные элементы
  Widget _buildBackgroundElements() {
    return Positioned.fill(child: CustomPaint(painter: _BackgroundPainter()));
  }

  /// Логотип с улучшенным дизайном
  Widget _buildLogo() {
    return OptimizedWidget(
      child: Container(
        width: 180,
        height: 180,
        padding: const EdgeInsets.all(20),
        child: Image.asset(
          'assets/icon/icon.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Логируем ошибку для отладки
            debugPrint('Ошибка загрузки логотипа: $error');
            debugPrint('Путь: assets/icon/icon.png');
            // Fallback на иконку, если изображение не найдено
            return Icon(
              Icons.favorite_rounded,
              size: 100,
              color: AppConfig.primaryColor,
            );
          },
        ),
      ),
    );
  }

  /// Название приложения
  Widget _buildAppTitle() {
    return OptimizedWidget(
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: [
            AppConfig.primaryColor,
            AppConfig.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: Text(
          AppConfig.appName,
          style: GoogleFonts.firaSans(
            fontSize: 44,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  /// Слоган
  Widget _buildSlogan() {
    return OptimizedWidget(
      child: Text(
        'Забота о Вас — каждый час',
        style: GoogleFonts.firaSans(
          fontSize: 20,
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Индикатор загрузки
  Widget _buildLoadingIndicator() {
    return OptimizedWidget(
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Внешний круг с градиентом
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppConfig.primaryColor.withOpacity(0.1),
                    AppConfig.primaryColor.withOpacity(0.05),
                  ],
                ),
              ),
            ),
            // Индикатор загрузки
            SizedBox(
              width: 52,
              height: 52,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppConfig.primaryColor,
                ),
                strokeWidth: 4,
                backgroundColor: AppConfig.primaryColor.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Кастомный painter для фоновых элементов
class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppConfig.primaryColor.withOpacity(0.03);

    // Верхний левый круг
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.15),
      size.width * 0.2,
      paint,
    );

    // Нижний правый круг
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.85),
      size.width * 0.25,
      paint,
    );

    // Центральный размытый элемент
    final gradientPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppConfig.primaryColor.withOpacity(0.05),
              AppConfig.primaryColor.withOpacity(0.0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.5, size.height * 0.4),
              radius: size.width * 0.4,
            ),
          );

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.4),
      size.width * 0.4,
      gradientPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
