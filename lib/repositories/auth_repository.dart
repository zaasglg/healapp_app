import 'dart:convert';
import 'dart:io';
import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../utils/app_logger.dart';

// Импортируем глобальный экземпляр
final _defaultApiClient = apiClient;

/// Модель пользователя
class User {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? middleName;
  final String? email;
  final String phone;
  final String? accountType;
  final List<String>? roles;
  final Map<String, dynamic>? organization;
  final Map<String, dynamic>? additionalData;
  final String? avatar;

  User({
    required this.id,
    this.firstName,
    this.lastName,
    this.middleName,
    this.email,
    required this.phone,
    this.accountType,
    this.roles,
    this.organization,
    this.additionalData,
    this.avatar,
  });

  /// Полное имя пользователя
  String? get fullName {
    final parts = <String>[];
    if (firstName != null && firstName!.isNotEmpty) parts.add(firstName!);
    if (lastName != null && lastName!.isNotEmpty) parts.add(lastName!);
    if (middleName != null && middleName!.isNotEmpty) parts.add(middleName!);
    return parts.isNotEmpty ? parts.join(' ') : null;
  }

  /// Для обратной совместимости
  String? get name => fullName;

  /// Получить имя для отображения (организация или имя сиделки)
  String get displayName {
    // Для частной сиделки, клиента, врача или сотрудника организации показываем имя и фамилию
    if (accountType == 'specialist' ||
        accountType == 'client' ||
        accountType == 'doctor' ||
        accountType == 'caregiver') {
      final fName = firstName?.trim() ?? '';
      final lName = lastName?.trim() ?? '';

      if (fName.isNotEmpty || lName.isNotEmpty) {
        return '$fName $lName'.trim();
      }

      // Пробуем поле name из additionalData
      if (additionalData != null) {
        final name = (additionalData!['name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          return name;
        }
      }

      // Если имя не заполнено, показываем телефон
      return phone;
    }

    // Для пансионата с именем и фамилией показываем персональные данные
    if (accountType == 'pansionat') {
      final fName = firstName?.trim() ?? '';
      final lName = lastName?.trim() ?? '';

      if (fName.isNotEmpty || lName.isNotEmpty) {
        return '$fName $lName'.trim();
      }
    }

    // Для организаций показываем название организации
    if (organization != null) {
      final name = (organization!['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) return name;
    }

    // Fallback
    return fullName ?? phone;
  }

  /// Получить отображаемый контакт
  String get displayContact {
    if (email != null && email!.trim().isNotEmpty) return email!.trim();
    if (phone.isNotEmpty) return phone;
    return '';
  }

  factory User.fromJson(Map<String, dynamic> json) {
    // Извлекаем роли из разных возможных мест в ответе
    List<String>? roles;

    // API может возвращать 'roles' (массив) или 'role' (строка)
    final rolesData = json['roles'];
    final roleData = json['role'];

    // Логируем для отладки
    log.d(
      'User.fromJson: accountType=${json['account_type']}, roles=$rolesData, role=$roleData',
    );

    if (rolesData is List) {
      // Массив ролей (для сотрудников организации)
      roles = rolesData.map((r) {
        if (r is Map) {
          return r['name']?.toString() ?? '';
        }
        return r.toString();
      }).toList();
    } else if (roleData is String && roleData.isNotEmpty) {
      // Одна роль в виде строки (для клиентов)
      roles = [roleData];
    }

    // Извлекаем организацию
    Map<String, dynamic>? organization;
    if (json['organization'] is Map<String, dynamic>) {
      organization = json['organization'] as Map<String, dynamic>;
    }

    return User(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      middleName: json['middle_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone']?.toString() ?? '',
      accountType: json['account_type'] as String?,
      roles: roles,
      organization: organization,
      additionalData: json,
      avatar: json['avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'middle_name': middleName,
      'email': email,
      'phone': phone,
      'account_type': accountType,
      'roles': roles,
      'organization': organization,
      ...?additionalData,
    };
  }

  /// Проверить, есть ли у пользователя определённая роль
  bool hasRole(String role) {
    return roles?.contains(role) ?? false;
  }

  @override
  String toString() {
    return 'User(id: $id, phone: $phone, name: $fullName, accountType: $accountType, roles: $roles)';
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

      // Проверяем формат ответа - может быть {'user': {...}} или напрямую данные пользователя
      Map<String, dynamic>? userData;
      if (data.containsKey('user') && data['user'] is Map<String, dynamic>) {
        userData = data['user'] as Map<String, dynamic>;
      } else if (data.containsKey('id')) {
        // Данные пользователя возвращаются напрямую
        userData = data;
      }

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

      // Проверяем формат ответа - может быть {'user': {...}} или напрямую данные пользователя
      Map<String, dynamic>? userData;
      if (data.containsKey('user') && data['user'] is Map<String, dynamic>) {
        userData = data['user'] as Map<String, dynamic>;
      } else if (data.containsKey('id')) {
        // Данные пользователя возвращаются напрямую
        userData = data;
      }

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

      // Проверяем формат ответа - может быть {'user': {...}} или напрямую данные пользователя
      Map<String, dynamic>? userData;
      if (responseData.containsKey('user') &&
          responseData['user'] is Map<String, dynamic>) {
        userData = responseData['user'] as Map<String, dynamic>;
      } else if (responseData.containsKey('id')) {
        // Данные пользователя возвращаются напрямую
        userData = responseData;
      }

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
