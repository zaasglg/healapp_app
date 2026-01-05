import 'dart:async';
import 'package:app_links/app_links.dart';
import '../utils/app_logger.dart';

/// Сервис для обработки Deep Links
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  /// Callback для обработки токена приглашения
  Function(String token)? onInviteReceived;

  /// Инициализация сервиса
  Future<void> initialize() async {
    _appLinks = AppLinks();

    // Обработка ссылки при запуске приложения (cold start)
    await _handleInitialLink();

    // Подписка на входящие ссылки (когда приложение уже запущено)
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _handleLink(uri);
      },
      onError: (err) {
        log.e('Ошибка deep link: $err');
      },
    );

    log.i('DeepLinkService инициализирован');
  }

  /// Обработка начальной ссылки (при запуске приложения)
  Future<void> _handleInitialLink() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleLink(initialUri);
      }
    } catch (e) {
      log.e('Ошибка получения initial link: $e');
    }
  }

  /// Обработка ссылки
  void _handleLink(Uri uri) {
    log.i('Deep link получен: $uri');
    log.d(
      'scheme: ${uri.scheme}, host: ${uri.host}, path: ${uri.path}, segments: ${uri.pathSegments}',
    );

    String? token;

    // Обрабатываем custom scheme healapp://invite/token или healapp://invite?token=xxx
    if (uri.scheme == 'healapp' && uri.host == 'invite') {
      if (uri.pathSegments.isNotEmpty) {
        token = uri.pathSegments.first;
      } else if (uri.path.isNotEmpty && uri.path != '/') {
        // Если путь есть но pathSegments пустой
        token = uri.path.replaceFirst('/', '');
      }
    }

    // Обрабатываем HTTPS ссылки: https://domain/invite/{token}
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'invite') {
        if (uri.pathSegments.length > 1) {
          token = uri.pathSegments[1];
        }
      }
    }

    if (token != null && token.isNotEmpty) {
      log.i('Токен приглашения извлечён: $token');
      onInviteReceived?.call(token);
    } else {
      log.w('Токен не найден в ссылке');
    }
  }

  /// Освобождение ресурсов
  void dispose() {
    _linkSubscription?.cancel();
  }
}
