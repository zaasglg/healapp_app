import '../network/api_exceptions.dart';
import 'package:healapp_mobile/core/logging/app_logger.dart';

/// Централизованный обработчик ошибок для BLoC
class ErrorHandler {
  /// Обработать исключение и вернуть понятное пользователю сообщение
  static String handleError(Object error, StackTrace? stackTrace) {
    // Логируем ошибку с полной информацией
    log.error(
      'ErrorHandler: processing error',
      error: error,
      stackTrace: stackTrace,
    );

    // Обрабатываем известные типы ошибок
    if (error is ValidationException) {
      final errors = error.getAllErrors();
      return errors.isNotEmpty ? errors.join(', ') : error.message;
    }

    if (error is UnauthorizedException) {
      return 'Требуется авторизация';
    }

    if (error is ForbiddenException) {
      return 'Доступ запрещён';
    }

    if (error is NotFoundException) {
      return error.message.isNotEmpty ? error.message : 'Данные не найдены';
    }

    if (error is ConflictException) {
      return error.message.isNotEmpty ? error.message : 'Конфликт данных';
    }

    if (error is NetworkException) {
      return 'Ошибка сети: ${error.message}';
    }

    if (error is ServerException) {
      return 'Ошибка сервера: ${error.message}';
    }

    if (error is ApiException) {
      return error.message;
    }

    // Для неизвестных ошибок логируем детали
    log.error('ErrorHandler: unknown error type ${error.runtimeType}');
    return 'Произошла ошибка. Попробуйте позже';
  }

  /// Обработать ошибку авторизации (более специфичные сообщения)
  static String handleAuthError(Object error, StackTrace? stackTrace) {
    log.error(
      'ErrorHandler: processing auth error',
      error: error,
      stackTrace: stackTrace,
    );

    if (error is ValidationException) {
      final errors = error.getAllErrors();
      return errors.isNotEmpty ? errors.join(', ') : error.message;
    }

    if (error is UnauthorizedException) {
      return 'Неверный номер телефона или пароль';
    }

    if (error is NetworkException) {
      return 'Ошибка сети: ${error.message}';
    }

    if (error is ServerException) {
      return 'Ошибка сервера: ${error.message}';
    }

    if (error is ApiException) {
      return error.message;
    }

    log.error('ErrorHandler: unknown auth error type ${error.runtimeType}');
    return 'Ошибка авторизации. Попробуйте позже';
  }
}
