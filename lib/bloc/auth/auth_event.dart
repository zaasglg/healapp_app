import 'package:equatable/equatable.dart';

/// Базовый класс для событий авторизации
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Событие запроса входа в систему
class AuthLoginRequested extends AuthEvent {
  final String phone;
  final String password;

  const AuthLoginRequested({required this.phone, required this.password});

  @override
  List<Object?> get props => [phone, password];
}

/// Событие запроса выхода из системы
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Событие запроса регистрации
class AuthRegisterRequested extends AuthEvent {
  final String phone;
  final String password;
  final String passwordConfirmation;
  final String firstName;
  final String lastName;
  final String accountType;
  final String? organizationName;
  final String? referralCode;

  const AuthRegisterRequested({
    required this.phone,
    required this.password,
    required this.passwordConfirmation,
    required this.firstName,
    required this.lastName,
    required this.accountType,
    this.organizationName,
    this.referralCode,
  });

  @override
  List<Object?> get props => [
    phone,
    password,
    passwordConfirmation,
    firstName,
    lastName,
    accountType,
    organizationName,
    referralCode,
  ];
}

/// Событие проверки статуса авторизации
class AuthCheckStatus extends AuthEvent {
  const AuthCheckStatus();
}

/// Событие подтверждения телефона по SMS-коду
class AuthVerifyPhoneRequested extends AuthEvent {
  final String phone;
  final String code;

  const AuthVerifyPhoneRequested({required this.phone, required this.code});

  @override
  List<Object?> get props => [phone, code];
}
