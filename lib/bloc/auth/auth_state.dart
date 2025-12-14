import 'package:equatable/equatable.dart';
import '../../repositories/auth_repository.dart';

/// Базовый класс для состояний авторизации
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Начальное состояние
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Состояние загрузки
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Состояние успешной авторизации
class AuthAuthenticated extends AuthState {
  final User user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

/// Состояние неавторизованного пользователя
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Состояние ошибки авторизации
class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);

  @override
  List<Object?> get props => [message];
}

/// Состояние ожидания подтверждения SMS после регистрации
class AuthAwaitingSmsVerification extends AuthState {
  final String phone;
  final String message;

  const AuthAwaitingSmsVerification({
    required this.phone,
    required this.message,
  });

  @override
  List<Object?> get props => [phone, message];
}
