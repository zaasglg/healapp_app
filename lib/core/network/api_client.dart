import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_exceptions.dart';
import '../../utils/app_logger.dart';

/// Конфигурация API клиента
class ApiConfig {
  static const String baseUrl = 'https://api.sistemizdorovya.ru/api/v1';
  static const String baseDomain = 'https://api.sistemizdorovya.ru';
  static const String tokenKey = 'auth_token';
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  /// Преобразует относительный путь в полный URL
  /// Например: /storage/avatars/1/image.jpg -> https://api.sistemizdorovya.ru/storage/avatars/1/image.jpg
  static String getFullUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) {
      return '';
    }

    // Если путь уже является полным URL, возвращаем как есть
    if (relativePath.startsWith('http://') ||
        relativePath.startsWith('https://')) {
      return relativePath;
    }

    // Убираем начальный слеш, если он есть
    final cleanPath = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : relativePath;

    return '$baseDomain/$cleanPath';
  }
}

/// Callback для уведомления о необходимости выхода из системы
typedef OnUnauthorizedCallback = void Function();

/// Клиент для работы с API
class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  OnUnauthorizedCallback? _onUnauthorized;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        // На Web sendTimeout вызывает ошибку для запросов без тела (например, GET)
        sendTimeout: kIsWeb ? null : ApiConfig.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(_AuthInterceptor(_storage, _onUnauthorizedCallback));
  }

  /// Установить callback для обработки неавторизованных запросов
  void setOnUnauthorizedCallback(OnUnauthorizedCallback? callback) {
    _onUnauthorized = callback;
  }

  /// Callback для interceptor
  void _onUnauthorizedCallback() {
    _onUnauthorized?.call();
  }

  /// GET запрос
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final fullUrl = '${_dio.options.baseUrl}$path';
      log.d('ApiClient: GET запрос к $fullUrl');
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      log.d('ApiClient: GET успешен, статус: ${response.statusCode}');
      return response;
    } on DioException catch (e) {
      log.e(
        'ApiClient: DioException при GET $path: ${e.type}, message: ${e.message}',
      );
      if (e.error != null) {
        log.e('ApiClient: Underlying error: ${e.error}');
      }
      throw ApiExceptionHandler.handleDioException(e);
    }
  }

  /// POST запрос
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final fullUrl = '${_dio.options.baseUrl}$path';
      log.d('ApiClient: 📤 POST запрос к $fullUrl');
      log.d('ApiClient: 📦 Данные: $data');
      if (queryParameters != null) {
        log.d('ApiClient: 🔍 Query параметры: $queryParameters');
      }

      final startTime = DateTime.now();
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

      final duration = DateTime.now().difference(startTime);
      log.d(
        'ApiClient: ✅ POST успешен за ${duration.inMilliseconds}ms, статус: ${response.statusCode}',
      );
      log.d('ApiClient: 📥 Ответ: ${response.data}');

      return response;
    } on DioException catch (e) {
      log.e(
        'ApiClient: ❌ DioException при POST $path: ${e.type}, message: ${e.message}',
      );
      if (e.response != null) {
        log.e('ApiClient: 📛 Response status: ${e.response?.statusCode}');
        log.e('ApiClient: 📛 Response data: ${e.response?.data}');
      }
      if (e.error != null) {
        log.e('ApiClient: 📛 Underlying error: ${e.error}');
      }
      throw ApiExceptionHandler.handleDioException(e);
    } catch (e) {
      log.e('ApiClient: ❌ Неизвестная ошибка при POST $path: $e');
      rethrow;
    }
  }

  /// PUT запрос
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw ApiExceptionHandler.handleDioException(e);
    }
  }

  /// PATCH запрос
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw ApiExceptionHandler.handleDioException(e);
    }
  }

  /// DELETE запрос
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw ApiExceptionHandler.handleDioException(e);
    }
  }

  /// POST запрос с загрузкой файла (multipart/form-data)
  Future<Response<T>> postFile<T>(
    String path, {
    required File file,
    required String fieldName,
    Map<String, dynamic>? additionalFields,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final fileName = file.path.split('/').last;
      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(file.path, filename: fileName),
        if (additionalFields != null) ...additionalFields,
      });

      return await _dio.post<T>(
        path,
        data: formData,
        options: Options(
          headers: {
            'Accept': 'application/json',
            // Content-Type с boundary будет установлен автоматически Dio
          },
        ),
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw ApiExceptionHandler.handleDioException(e);
    }
  }

  /// Сохранить токен авторизации
  Future<void> saveToken(String token) async {
    await _storage.write(key: ApiConfig.tokenKey, value: token);
  }

  /// Получить токен авторизации
  Future<String?> getToken() async {
    return await _storage.read(key: ApiConfig.tokenKey);
  }

  /// Удалить токен авторизации
  Future<void> deleteToken() async {
    await _storage.delete(key: ApiConfig.tokenKey);
  }

  /// Очистить все данные хранилища
  Future<void> clearStorage() async {
    await _storage.deleteAll();
  }
}

/// Interceptor для добавления токена авторизации и обработки 401
class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  final VoidCallback? onUnauthorized;

  _AuthInterceptor(this._storage, this.onUnauthorized);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    log.d(
      '🔐 AuthInterceptor: onRequest для ${options.method} ${options.path}',
    );

    // Читаем токен из безопасного хранилища
    final token = await _storage.read(key: ApiConfig.tokenKey);

    // Если токен существует, добавляем его в заголовок Authorization
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      log.d('🔑 AuthInterceptor: Токен добавлен в заголовок');
    } else {
      log.w('⚠️ AuthInterceptor: Токен не найден');
    }

    super.onRequest(options, handler);
    log.d('✅ AuthInterceptor: Запрос отправлен');
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Если получили 401 Unauthorized, вызываем callback для выхода
    if (err.response?.statusCode == 401) {
      onUnauthorized?.call();
    }

    super.onError(err, handler);
  }
}

/// Глобальный экземпляр API клиента
final apiClient = ApiClient();
