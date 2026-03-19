import 'package:healapp_mobile/core/logging/app_logger.dart';

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
    if (accountType == 'specialist' ||
        accountType == 'client' ||
        accountType == 'doctor' ||
        accountType == 'caregiver') {
      final fName = firstName?.trim() ?? '';
      final lName = lastName?.trim() ?? '';

      if (fName.isNotEmpty || lName.isNotEmpty) {
        return '$fName $lName'.trim();
      }

      if (additionalData != null) {
        final name = (additionalData!['name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          return name;
        }
      }

      return phone;
    }

    if (accountType == 'pansionat') {
      final fName = firstName?.trim() ?? '';
      final lName = lastName?.trim() ?? '';

      if (fName.isNotEmpty || lName.isNotEmpty) {
        return '$fName $lName'.trim();
      }
    }

    if (organization != null) {
      final name = (organization!['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) return name;
    }

    return fullName ?? phone;
  }

  /// Получить отображаемый контакт
  String get displayContact {
    if (email != null && email!.trim().isNotEmpty) return email!.trim();
    if (phone.isNotEmpty) return phone;
    return '';
  }

  factory User.fromJson(Map<String, dynamic> json) {
    List<String>? roles;

    final rolesData = json['roles'];
    final roleData = json['role'];

    log.d(
      'User.fromJson: accountType=${json['account_type']}, roles=$rolesData, role=$roleData',
    );

    if (rolesData is List) {
      roles = rolesData.map((r) {
        if (r is Map) {
          return r['name']?.toString() ?? '';
        }
        return r.toString();
      }).toList();
    } else if (roleData is String && roleData.isNotEmpty) {
      roles = [roleData];
    }

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
