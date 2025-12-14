import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';

// Импортируем глобальный экземпляр
final _defaultApiClient = apiClient;

/// Модель пользователя
class User {
  final String id;
  final String? name;
  final String? email;
  final String phone;
  final String? accountType;
  final List<String>? roles;
  final Map<String, dynamic>? additionalData;

  User({
    required this.id,
    this.name,
    this.email,
    required this.phone,
    this.accountType,
    this.roles,
    this.additionalData,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Извлекаем роли из разных возможных мест в ответе
    List<String>? roles;
    final rolesData = json['roles'];
    if (rolesData is List) {
      roles = rolesData.map((r) {
        if (r is Map) {
          return r['name']?.toString() ?? '';
        }
        return r.toString();
      }).toList();
    }

    return User(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone']?.toString() ?? '',
      accountType: json['account_type'] as String?,
      roles: roles,
      additionalData: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'account_type': accountType,
      'roles': roles,
      ...?additionalData,
    };
  }

  /// Проверить, есть ли у пользователя определённая роль
  bool hasRole(String role) {
    return roles?.contains(role) ?? false;
  }
}

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

  /// Регистрация нового пользователя
  ///
  /// [data] - данные для регистрации:
  ///   - phone: номер телефона
  ///   - password: пароль
  ///   - first_name: имя
  ///   - last_name: фамилия
  ///   - account_type: тип аккаунта (pansionat, agency, specialist)
  ///   - referral_code (опционально): реферальный код
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

      // Извлекаем данные пользователя
      final userData = data['user'] as Map<String, dynamic>?;
      if (userData == null) {
        throw const ServerException('Данные пользователя не получены');
      }

      return User.fromJson(userData);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при получении данных: ${e.toString()}');
    }
  }
}
