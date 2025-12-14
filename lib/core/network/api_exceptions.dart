import 'package:dio/dio.dart';

/// Базовый класс для исключений API
abstract class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

/// Ошибка сети (нет подключения, таймаут и т.д.)
class NetworkException extends ApiException {
  const NetworkException(super.message, [super.statusCode]);
}

/// Ошибка сервера (500, 502, 503 и т.д.)
class ServerException extends ApiException {
  const ServerException(super.message, [super.statusCode]);
}

/// Ошибка авторизации (401)
class UnauthorizedException extends ApiException {
  const UnauthorizedException(super.message, [super.statusCode]);
}

/// Ошибка доступа (403)
class ForbiddenException extends ApiException {
  const ForbiddenException(super.message, [super.statusCode]);
}

/// Ошибка не найдено (404)
class NotFoundException extends ApiException {
  const NotFoundException(super.message, [super.statusCode]);
}

/// Ошибка валидации Laravel (422)
class ValidationException extends ApiException {
  final Map<String, List<String>> errors;

  const ValidationException(super.message, this.errors, [super.statusCode]);

  /// Получить первую ошибку для поля
  String? getFirstError(String field) {
    return errors[field]?.first;
  }

  /// Получить все ошибки для поля
  List<String>? getErrors(String field) {
    return errors[field];
  }

  /// Получить все ошибки в виде списка
  List<String> getAllErrors() {
    final List<String> allErrors = [];
    errors.forEach((field, messages) {
      allErrors.addAll(messages);
    });
    return allErrors;
  }

  @override
  String toString() {
    if (errors.isEmpty) return message;
    return 'Validation Error: ${errors.entries.map((e) => '${e.key}: ${e.value.join(", ")}').join("; ")}';
  }
}

/// Обработчик исключений API
class ApiExceptionHandler {
  /// Преобразовать DioException в ApiException
  static ApiException handleDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException(
          'Превышено время ожидания соединения',
          error.response?.statusCode,
        );

      case DioExceptionType.badResponse:
        return _handleResponseError(error.response);

      case DioExceptionType.cancel:
        return NetworkException('Запрос был отменен');

      case DioExceptionType.connectionError:
        return NetworkException(
          'Ошибка подключения к серверу. Проверьте интернет-соединение',
        );

      case DioExceptionType.badCertificate:
        return NetworkException('Ошибка сертификата');

      case DioExceptionType.unknown:
        return NetworkException(
          error.message ?? 'Неизвестная ошибка сети',
          error.response?.statusCode,
        );
    }
  }

  /// Обработать ошибку ответа сервера
  static ApiException _handleResponseError(Response? response) {
    if (response == null) {
      return NetworkException('Пустой ответ от сервера');
    }

    final statusCode = response.statusCode ?? 0;
    final data = response.data;

    // Обработка ошибок валидации Laravel (422)
    if (statusCode == 422 && data is Map<String, dynamic>) {
      final errors = <String, List<String>>{};

      // Laravel возвращает ошибки в формате: {"errors": {"field": ["message"]}}
      if (data.containsKey('errors') && data['errors'] is Map) {
        final errorsMap = data['errors'] as Map<String, dynamic>;
        errorsMap.forEach((key, value) {
          if (value is List) {
            errors[key] = value.map((e) => e.toString()).toList();
          } else {
            errors[key] = [value.toString()];
          }
        });
      } else {
        // Альтернативный формат: {"field": ["message"]}
        data.forEach((key, value) {
          if (value is List) {
            errors[key] = value.map((e) => e.toString()).toList();
          } else if (value is String) {
            errors[key] = [value];
          }
        });
      }

      final message = data['message'] as String? ?? 'Ошибка валидации данных';

      return ValidationException(message, errors, statusCode);
    }

    // Обработка других HTTP ошибок
    final message = _extractErrorMessage(data) ?? 'Ошибка сервера: $statusCode';

    switch (statusCode) {
      case 401:
        return UnauthorizedException(message, statusCode);
      case 403:
        return ForbiddenException(message, statusCode);
      case 404:
        return NotFoundException(message, statusCode);
      case 500:
      case 502:
      case 503:
        return ServerException(message, statusCode);
    }

    // Для всех остальных статус кодов возвращаем ServerException
    if (statusCode >= 500) {
      return ServerException(message, statusCode);
    }
    return ServerException(message, statusCode);
  }

  /// Извлечь сообщение об ошибке из ответа
  static String? _extractErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['message'] as String?;
    }
    if (data is String) {
      return data;
    }
    return null;
  }
}
