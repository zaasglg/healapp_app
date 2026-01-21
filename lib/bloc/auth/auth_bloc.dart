import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/auth_repository.dart';
import '../../core/network/api_exceptions.dart';
import '../../utils/app_logger.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// BLoC для управления авторизацией
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({AuthRepository? authRepository})
    : _authRepository = authRepository ?? AuthRepository(),
      super(const AuthInitial()) {
    log.i('Инициализация AuthBloc с обработчиками');
    log.d(
      'AuthLoginRequested, AuthRegisterRequested, AuthVerifyPhoneRequested',
    );
    log.d('AuthLogoutRequested, AuthCheckStatus, AuthRefreshUser');

    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLoginWithToken>(_onLoginWithToken);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthVerifyPhoneRequested>(_onVerifyPhoneRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthCheckStatus>(_onCheckStatus);
    on<AuthRefreshUser>(_onRefreshUser);
    on<AuthUploadAvatarRequested>(_onUploadAvatarRequested);
    on<AuthUpdateProfileRequested>(_onUpdateProfileRequested);

    log.i('AuthBloc инициализирован успешно');
  }

  /// Обработка события входа в систему
  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final user = await _authRepository.login(event.phone, event.password);

      emit(AuthAuthenticated(user));
    } on ValidationException catch (e) {
      // Обработка ошибок валидации
      final errorMessage = e.getAllErrors().isNotEmpty
          ? e.getAllErrors().join(', ')
          : e.message;
      emit(AuthFailure(errorMessage));
    } on UnauthorizedException {
      emit(const AuthFailure('Неверный номер телефона или пароль'));
    } on NetworkException catch (e) {
      emit(AuthFailure('Ошибка сети: ${e.message}'));
    } on ServerException catch (e) {
      emit(AuthFailure('Ошибка сервера: ${e.message}'));
    } on ApiException catch (e) {
      emit(AuthFailure(e.message));
    } catch (_) {
      emit(const AuthFailure('Неизвестная ошибка'));
    }
  }

  /// Обработка события входа по токену
  Future<void> _onLoginWithToken(
    AuthLoginWithToken event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final user = await _authRepository.loginWithToken(event.token);
      emit(AuthAuthenticated(user));
    } on ValidationException catch (e) {
      final errorMessage = e.getAllErrors().isNotEmpty
          ? e.getAllErrors().join(', ')
          : e.message;
      emit(AuthFailure(errorMessage));
    } on UnauthorizedException {
      emit(const AuthFailure('Неверный токен авторизации'));
    } on NetworkException catch (e) {
      emit(AuthFailure('Ошибка сети: ${e.message}'));
    } on ServerException catch (e) {
      emit(AuthFailure('Ошибка сервера: ${e.message}'));
    } on ApiException catch (e) {
      emit(AuthFailure(e.message));
    } catch (_) {
      emit(const AuthFailure('Неизвестная ошибка'));
    }
  }

  /// Обработка события регистрации
  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final data = <String, dynamic>{
        'phone': event.phone,
        'password': event.password,
        'password_confirmation': event.passwordConfirmation,
        'account_type': event.accountType,
      };

      // Добавляем имя и фамилию только если они указаны
      if (event.firstName.isNotEmpty) {
        data['first_name'] = event.firstName;
      }
      if (event.lastName.isNotEmpty) {
        data['last_name'] = event.lastName;
      }

      // Добавляем название организации, если передано и требуется для типа аккаунта
      if (event.organizationName != null &&
          event.organizationName!.isNotEmpty) {
        data['organization_name'] = event.organizationName;
      }

      // Добавляем реферальный код, если он указан
      if (event.referralCode != null && event.referralCode!.isNotEmpty) {
        data['referral_code'] = event.referralCode;
      }

      log.d('Отправка данных регистрации: $data');
      final response = await _authRepository.register(data);
      log.i('SMS отправлен. Ответ: $response');

      emit(
        AuthAwaitingSmsVerification(
          phone: response['phone'] as String,
          message: response['message'] as String,
        ),
      );
    } on ValidationException catch (e) {
      // Обработка ошибок валидации
      log.w('Ошибка валидации: ${e.message}');
      log.w('Все ошибки: ${e.getAllErrors()}');
      final errorMessage = e.getAllErrors().isNotEmpty
          ? e.getAllErrors().join(', ')
          : e.message;
      emit(AuthFailure(errorMessage));
    } on UnauthorizedException catch (e) {
      log.e('Ошибка авторизации: $e');
      emit(const AuthFailure('Ошибка при регистрации'));
    } on NetworkException catch (e) {
      log.e('Ошибка сети: ${e.message}');
      emit(AuthFailure('Ошибка сети: ${e.message}'));
    } on ServerException catch (e) {
      log.e('Ошибка сервера: ${e.message}');
      emit(AuthFailure('Ошибка сервера: ${e.message}'));
    } on ApiException catch (e) {
      log.e('API ошибка: ${e.message}');
      emit(AuthFailure(e.message));
    } catch (e) {
      log.e('Неизвестная ошибка: $e');
      emit(const AuthFailure('Неизвестная ошибка'));
    }
  }

  /// Обработка события подтверждения телефона
  Future<void> _onVerifyPhoneRequested(
    AuthVerifyPhoneRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      log.d(
        'Отправка кода подтверждения: phone=${event.phone}, code=${event.code}',
      );
      final user = await _authRepository.verifyPhone(event.phone, event.code);
      log.i('Телефон подтвержден. Пользователь: $user');

      emit(AuthAuthenticated(user));
    } on ValidationException catch (e) {
      log.w('Ошибка валидации: ${e.message}');
      log.w('Все ошибки: ${e.getAllErrors()}');
      final errorMessage = e.getAllErrors().isNotEmpty
          ? e.getAllErrors().join(', ')
          : e.message;
      emit(AuthFailure(errorMessage));
    } on UnauthorizedException catch (e) {
      log.e('Ошибка авторизации: $e');
      emit(const AuthFailure('Неверный код подтверждения'));
    } on NetworkException catch (e) {
      log.e('Ошибка сети: ${e.message}');
      emit(AuthFailure('Ошибка сети: ${e.message}'));
    } on ServerException catch (e) {
      log.e('Ошибка сервера: ${e.message}');
      emit(AuthFailure('Ошибка сервера: ${e.message}'));
    } on ApiException catch (e) {
      log.e('API ошибка: ${e.message}');
      emit(AuthFailure(e.message));
    } catch (e) {
      log.e('Неизвестная ошибка: $e');
      emit(const AuthFailure('Неизвестная ошибка'));
    }
  }

  /// Обработка события выхода из системы
  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      await _authRepository.logout();
      emit(const AuthUnauthenticated());
    } catch (e) {
      // Даже если произошла ошибка, считаем что выход выполнен
      emit(const AuthUnauthenticated());
    }
  }

  /// Обработка события проверки статуса авторизации
  Future<void> _onCheckStatus(
    AuthCheckStatus event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final isAuthenticated = await _authRepository.isAuthenticated();
      if (isAuthenticated) {
        // Получаем текущего пользователя
        final user = await _authRepository.getCurrentUser();
        log.i('Пользователь загружен из кэша: $user');
        emit(AuthAuthenticated(user));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      log.d('Пользователь не авторизован: $e');
      emit(const AuthUnauthenticated());
    }
  }

  /// Обработка события обновления данных пользователя
  Future<void> _onRefreshUser(
    AuthRefreshUser event,
    Emitter<AuthState> emit,
  ) async {
    // Не показываем индикатор загрузки, обновляем данные в фоне
    try {
      final isAuthenticated = await _authRepository.isAuthenticated();
      if (isAuthenticated) {
        final user = await _authRepository.getCurrentUser();
        log.d('Данные пользователя обновлены: $user');
        emit(AuthAuthenticated(user));
      }
    } catch (e) {
      log.w('Ошибка обновления данных пользователя: $e');
      // Не меняем состояние при ошибке обновления
    }
  }

  /// Обработка события загрузки аватара
  Future<void> _onUploadAvatarRequested(
    AuthUploadAvatarRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Не меняем состояние на Loading, чтобы не скрывать текущий UI
    try {
      final avatarFile = File(event.filePath);
      if (!await avatarFile.exists()) {
        emit(AuthFailure('Файл не найден'));
        return;
      }

      log.d('Загрузка аватара: ${event.filePath}');
      final updatedUser = await _authRepository.uploadAvatar(avatarFile);
      log.i('Аватар успешно загружен. Пользователь: $updatedUser');

      // Обновляем состояние с новыми данными пользователя
      emit(AuthAuthenticated(updatedUser));
    } on ValidationException catch (e) {
      log.w('Ошибка валидации: ${e.message}');
      final errorMessage = e.getAllErrors().isNotEmpty
          ? e.getAllErrors().join(', ')
          : e.message;
      emit(AuthFailure(errorMessage));
    } on NetworkException catch (e) {
      log.e('Ошибка сети: ${e.message}');
      emit(AuthFailure('Ошибка сети: ${e.message}'));
    } on ServerException catch (e) {
      log.e('Ошибка сервера: ${e.message}');
      emit(AuthFailure('Ошибка сервера: ${e.message}'));
    } on ApiException catch (e) {
      log.e('API ошибка: ${e.message}');
      emit(AuthFailure(e.message));
    } catch (e) {
      log.e('Неизвестная ошибка: $e');
      emit(AuthFailure('Ошибка при загрузке аватара: ${e.toString()}'));
    }
  }

  /// Обработка события обновления профиля пользователя (для частной сиделки)
  Future<void> _onUpdateProfileRequested(
    AuthUpdateProfileRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      log.d(
        'Обновление профиля: firstName=${event.firstName}, lastName=${event.lastName}, city=${event.city}',
      );

      final updatedUser = await _authRepository.updateProfile(
        firstName: event.firstName,
        lastName: event.lastName,
        city: event.city,
      );

      log.i('Профиль обновлён. Пользователь: $updatedUser');
      emit(AuthAuthenticated(updatedUser));
    } on ValidationException catch (e) {
      log.w('Ошибка валидации: ${e.message}');
      final errorMessage = e.getAllErrors().isNotEmpty
          ? e.getAllErrors().join(', ')
          : e.message;
      emit(AuthFailure(errorMessage));
    } on NetworkException catch (e) {
      log.e('Ошибка сети: ${e.message}');
      emit(AuthFailure('Ошибка сети: ${e.message}'));
    } on ServerException catch (e) {
      log.e('Ошибка сервера: ${e.message}');
      emit(AuthFailure('Ошибка сервера: ${e.message}'));
    } on ApiException catch (e) {
      log.e('API ошибка: ${e.message}');
      emit(AuthFailure(e.message));
    } catch (e) {
      log.e('Неизвестная ошибка: $e');
      emit(AuthFailure('Ошибка при обновлении профиля: ${e.toString()}'));
    }
  }
}
