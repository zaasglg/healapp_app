import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/auth_repository.dart';
import '../../core/network/api_exceptions.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// BLoC для управления авторизацией
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({AuthRepository? authRepository})
    : _authRepository = authRepository ?? AuthRepository(),
      super(const AuthInitial()) {
    print('🔧 Инициализация AuthBloc с обработчиками:');
    print('   ✓ AuthLoginRequested');
    print('   ✓ AuthRegisterRequested');
    print('   ✓ AuthVerifyPhoneRequested');
    print('   ✓ AuthLogoutRequested');
    print('   ✓ AuthCheckStatus');

    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthVerifyPhoneRequested>(_onVerifyPhoneRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthCheckStatus>(_onCheckStatus);

    print('🔧 AuthBloc инициализирован успешно');
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

      print('📤 Отправка данных регистрации: $data');
      final response = await _authRepository.register(data);
      print('✅ SMS отправлен. Ответ: $response');

      emit(
        AuthAwaitingSmsVerification(
          phone: response['phone'] as String,
          message: response['message'] as String,
        ),
      );
    } on ValidationException catch (e) {
      // Обработка ошибок валидации
      print('❌ Ошибка валидации: ${e.message}');
      print('   Все ошибки: ${e.getAllErrors()}');
      final errorMessage = e.getAllErrors().isNotEmpty
          ? e.getAllErrors().join(', ')
          : e.message;
      emit(AuthFailure(errorMessage));
    } on UnauthorizedException catch (e) {
      print('❌ Ошибка авторизации: $e');
      emit(const AuthFailure('Ошибка при регистрации'));
    } on NetworkException catch (e) {
      print('❌ Ошибка сети: ${e.message}');
      emit(AuthFailure('Ошибка сети: ${e.message}'));
    } on ServerException catch (e) {
      print('❌ Ошибка сервера: ${e.message}');
      emit(AuthFailure('Ошибка сервера: ${e.message}'));
    } on ApiException catch (e) {
      print('❌ API ошибка: ${e.message}');
      emit(AuthFailure(e.message));
    } catch (e) {
      print('❌ Неизвестная ошибка: $e');
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
      print(
        '📤 Отправка кода подтверждения: phone=${event.phone}, code=${event.code}',
      );
      final user = await _authRepository.verifyPhone(event.phone, event.code);
      print('✅ Телефон подтвержден. Пользователь: $user');

      emit(AuthAuthenticated(user));
    } on ValidationException catch (e) {
      print('❌ Ошибка валидации: ${e.message}');
      print('   Все ошибки: ${e.getAllErrors()}');
      final errorMessage = e.getAllErrors().isNotEmpty
          ? e.getAllErrors().join(', ')
          : e.message;
      emit(AuthFailure(errorMessage));
    } on UnauthorizedException catch (e) {
      print('❌ Ошибка авторизации: $e');
      emit(const AuthFailure('Неверный код подтверждения'));
    } on NetworkException catch (e) {
      print('❌ Ошибка сети: ${e.message}');
      emit(AuthFailure('Ошибка сети: ${e.message}'));
    } on ServerException catch (e) {
      print('❌ Ошибка сервера: ${e.message}');
      emit(AuthFailure('Ошибка сервера: ${e.message}'));
    } on ApiException catch (e) {
      print('❌ API ошибка: ${e.message}');
      emit(AuthFailure(e.message));
    } catch (e) {
      print('❌ Неизвестная ошибка: $e');
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
        print('✅ Пользователь загружен из кэша: $user');
        emit(AuthAuthenticated(user));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      print('❌ Ошибка при проверке статуса: $e');
      emit(const AuthUnauthenticated());
    }
  }
}
