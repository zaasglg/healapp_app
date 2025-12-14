import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_exceptions.dart';

/// Конфигурация API клиента
class ApiConfig {
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1';
  static const String tokenKey = 'auth_token';
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
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
        sendTimeout: ApiConfig.sendTimeout,
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
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
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
      return await _dio.post<T>(
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
    // Читаем токен из безопасного хранилища
    final token = await _storage.read(key: ApiConfig.tokenKey);

    // Если токен существует, добавляем его в заголовок Authorization
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    super.onRequest(options, handler);
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
