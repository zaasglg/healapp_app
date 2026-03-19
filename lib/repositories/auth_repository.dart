import 'dart:convert';
import 'dart:io';
import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import 'package:healapp_mobile/core/logging/app_logger.dart';
import '../models/user.dart';

export '../models/user.dart';

final _defaultApiClient = apiClient;

/// Репозиторий для работы с авторизацией
class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? _defaultApiClient;

  /// Вход в систему
  ///
  /// [phone] - номер телефона
  /// [password] - пароль
  ///
  /// Возвращает [User] при успешной авторизации
  /// Выбрасывает [ApiException] при ошибке
  Future<User> login(String phone, String password) async {
    try {
      final response = await _apiClient.post(
        '/auth/login',
        data: {'phone': phone, 'password': password},
      );

      final data = response.data as Map<String, dynamic>;

      // Извлекаем токен из ответа (может быть 'token' или 'access_token')
      final token = (data['access_token'] ?? data['token']) as String?;
      if (token == null || token.isEmpty) {
        throw const ServerException('Токен не получен от сервера');
      }

      // Сохраняем токен в безопасное хранилище
      await _apiClient.saveToken(token);

      // Извлекаем данные пользователя
      final userData = data['user'] as Map<String, dynamic>?;
      if (userData == null) {
        throw const ServerException('Данные пользователя не получены');
      }

      return User.fromJson(userData);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при входе: ${e.toString()}');
    }
  }

  /// Авторизация по токену (для Web redirect)
  ///
  /// [token] - токен доступа
  ///
  /// Возвращает [User] при успешной авторизации
  /// Выбрасывает [ApiException] при ошибке
  Future<User> loginWithToken(String token) async {
    try {
      // Сохраняем токен
      await _apiClient.saveToken(token);

      // Получаем данные пользователя
      return await getCurrentUser();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при входе по токену: ${e.toString()}');
    }
  }

  /// Регистрация нового пользователя
  ///
  /// [data] - данные для регистрации:
  ///   - phone: номер телефона
  ///   - password: пароль
  ///   - first_name: имя
  ///   - last_name: фамилия
  ///   - account_type: тип аккаунта (pansionat, agency, specialist)
  ///   - referral_code (опционально): реферальный код
  ///   - is_agree: согласие с правилами (1 или 0)
  ///
  /// Возвращает Map с данными ответа (message, phone)
  /// Выбрасывает [ApiException] при ошибке
  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post('/auth/register', data: data);

      final responseData = response.data as Map<String, dynamic>;

      // Проверяем, что SMS отправлен
      final message = responseData['message'] as String?;
      final phone = responseData['phone'] as String?;

      if (message == null || phone == null) {
        throw const ServerException('Некорректный ответ от сервера');
      }

      return {'message': message, 'phone': phone};
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при регистрации: ${e.toString()}');
    }
  }

  /// Извлечь данные пользователя из ответа сервера.
  /// API может вернуть либо {'user': {...}}, либо напрямую объект пользователя.
  Map<String, dynamic>? _extractUserData(Map<String, dynamic> data) {
    if (data.containsKey('user') && data['user'] is Map<String, dynamic>) {
      return data['user'] as Map<String, dynamic>;
    }
    if (data.containsKey('id')) {
      return data;
    }
    return null;
  }

  /// Выход из системы
  Future<void> logout() async {
    try {
      // Запрос логаута на сервере
      await _apiClient.post('/auth/logout');
    } on ApiException {
      rethrow;
    } catch (e) {
      // Даже при ошибке продолжаем очищать локальные данные
      // чтобы не блокировать пользователя
      if (e is! ApiException) {
        // noop
      }
    } finally {
      // Очищаем токен и локальное хранилище в любом случае
      await _apiClient.deleteToken();
      await _apiClient.clearStorage();
    }
  }

  /// Проверка статуса авторизации
  Future<bool> isAuthenticated() async {
    final token = await _apiClient.getToken();
    return token != null && token.isNotEmpty;
  }

  /// Получить текущий токен
  Future<String?> getToken() async {
    return await _apiClient.getToken();
  }

  /// Подтверждение телефона по SMS-коду
  ///
  /// [phone] - номер телефона
  /// [code] - код из SMS
  ///
  /// Возвращает [User] при успешной верификации
  /// Выбрасывает [ApiException] при ошибке
  Future<User> verifyPhone(String phone, String code) async {
    try {
      final response = await _apiClient.post(
        '/auth/verify-phone',
        data: {'phone': phone, 'code': code},
      );

      final data = response.data as Map<String, dynamic>;

      // Извлекаем токен из ответа (может быть 'access_token' или 'token')
      final token = (data['access_token'] ?? data['token']) as String?;
      if (token == null || token.isEmpty) {
        throw const ServerException('Токен не получен от сервера');
      }

      // Сохраняем токен в безопасное хранилище
      await _apiClient.saveToken(token);

      // Извлекаем данные пользователя
      final userData = data['user'] as Map<String, dynamic>?;
      if (userData == null) {
        throw const ServerException('Данные пользователя не получены');
      }

      return User.fromJson(userData);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при подтверждении: ${e.toString()}');
    }
  }

  /// Получить данные текущего пользователя
  ///
  /// Возвращает [User] с текущими данными
  /// Выбрасывает [ApiException] при ошибке
  Future<User> getCurrentUser() async {
    try {
      final response = await _apiClient.get('/auth/me');

      final data = response.data as Map<String, dynamic>;

      final userData = _extractUserData(data);
      if (userData == null) {
        throw const ServerException('Данные пользователя не получены');
      }

      // Красивое логирование ответа /auth/me
      try {
        final prettyJson = const JsonEncoder.withIndent('  ').convert(data);
        log.d('⬇️ Ответ /auth/me:\n$prettyJson');
      } catch (e) {
        log.e('Ошибка при логировании ответа /auth/me: $e');
      }

      return User.fromJson(userData);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при получении данных: ${e.toString()}');
    }
  }

  /// Загрузить аватар пользователя
  ///
  /// [avatarFile] - файл изображения для загрузки
  ///
  /// Возвращает [User] с обновленными данными, включая URL аватара
  /// Выбрасывает [ApiException] при ошибке
  Future<User> uploadAvatar(File avatarFile) async {
    try {
      log.d('Начало загрузки аватара: ${avatarFile.path}');

      final response = await _apiClient.postFile(
        '/auth/avatar',
        file: avatarFile,
        fieldName: 'avatar',
        onSendProgress: (sent, total) {
          final progress = (sent / total * 100).toStringAsFixed(1);
          log.d('Прогресс загрузки: $progress%');
        },
      );

      final data = response.data as Map<String, dynamic>;

      final userData = _extractUserData(data);
      if (userData == null) {
        throw const ServerException('Данные пользователя не получены');
      }

      log.i('Аватар успешно загружен. URL: ${userData['avatar']}');

      return User.fromJson(userData);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при загрузке аватара: ${e.toString()}');
    }
  }

  /// Обновить профиль пользователя
  ///
  /// [firstName] - имя
  /// [lastName] - фамилия
  /// [city] - город (опционально)
  ///
  /// Возвращает [User] с обновленными данными
  /// Выбрасывает [ApiException] при ошибке
  Future<User> updateProfile({
    required String firstName,
    required String lastName,
    String? city,
  }) async {
    try {
      log.d(
        'Обновление профиля: firstName=$firstName, lastName=$lastName, city=$city',
      );

      final data = <String, dynamic>{
        'first_name': firstName,
        'last_name': lastName,
      };

      if (city != null && city.isNotEmpty) {
        data['city'] = city;
      }

      final response = await _apiClient.patch('/auth/profile', data: data);

      final responseData = response.data as Map<String, dynamic>;

      final userData = _extractUserData(responseData);
      if (userData == null) {
        throw const ServerException('Данные пользователя не получены');
      }

      log.i('Профиль успешно обновлён');

      return User.fromJson(userData);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при обновлении профиля: ${e.toString()}');
    }
  }
}
