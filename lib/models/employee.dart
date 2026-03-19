import 'package:healapp_mobile/core/logging/app_logger.dart';

/// Модель сотрудника
class Employee {
  final int id;
  final int? userId;
  final String? name;
  final String? firstName;
  final String? lastName;
  final String? middleName;
  final String? phone;
  final String role;
  final String? accountType;
  final String? avatarUrl;
  final DateTime? createdAt;

  Employee({
    required this.id,
    this.userId,
    this.name,
    this.firstName,
    this.lastName,
    this.middleName,
    this.phone,
    required this.role,
    this.accountType,
    this.avatarUrl,
    this.createdAt,
  });

  /// Полное имя сотрудника или название организации
  String get fullName {
    if (isOrganization) {
      if (name != null && name!.isNotEmpty) {
        return name!;
      }
    }

    final parts = <String>[];
    if (lastName != null && lastName!.isNotEmpty) parts.add(lastName!);
    if (firstName != null && firstName!.isNotEmpty) parts.add(firstName!);
    if (middleName != null && middleName!.isNotEmpty) parts.add(middleName!);

    if (parts.isNotEmpty) {
      return parts.join(' ');
    }

    if (name != null && name!.isNotEmpty) {
      return name!;
    }

    return 'Без имени';
  }

  /// Проверка является ли это организацией
  bool get isOrganization {
    if (accountType != null) {
      return accountType != 'specialist' && accountType != 'client';
    }
    return role == 'owner';
  }

  /// Отображаемое название роли на русском
  String get roleDisplayName {
    switch (role) {
      case 'owner':
        return 'Владелец';
      case 'admin':
        return 'Администратор';
      case 'doctor':
        return 'Врач';
      case 'caregiver':
        return 'Сиделка';
      default:
        return role;
    }
  }

  factory Employee.fromJson(Map<String, dynamic> json) {
    log.d('Employee.fromJson: $json');

    String? avatarUrl;
    if (json['avatar_url'] != null) {
      avatarUrl = json['avatar_url'] as String?;
    } else if (json['avatar'] != null) {
      avatarUrl = json['avatar'] as String?;
    } else if (json['photo'] != null) {
      avatarUrl = json['photo'] as String?;
    } else if (json['image'] != null) {
      avatarUrl = json['image'] as String?;
    }

    return Employee(
      id: json['id'] as int,
      userId: json['user_id'] as int?,
      name: json['name'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      middleName: json['middle_name'] as String?,
      phone: json['phone']?.toString(),
      role: json['role'] as String? ?? 'caregiver',
      accountType: json['account_type'] as String?,
      avatarUrl: avatarUrl,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'first_name': firstName,
      'last_name': lastName,
      'middle_name': middleName,
      'phone': phone,
      'role': role,
      'account_type': accountType,
      'avatar_url': avatarUrl,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Employee(id: $id, name: $fullName, role: $role, avatar: $avatarUrl)';
  }
}

/// Модель приглашения
class Invitation {
  final int id;
  final int organizationId;
  final int inviterId;
  final String token;
  final String type;
  final String? role;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final String? inviteUrl;

  Invitation({
    required this.id,
    required this.organizationId,
    required this.inviterId,
    required this.token,
    required this.type,
    this.role,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    this.inviteUrl,
  });

  /// Отображаемое название роли на русском
  String get roleDisplayName {
    switch (role) {
      case 'admin':
        return 'Администратор';
      case 'doctor':
        return 'Врач';
      case 'caregiver':
        return 'Сиделка';
      default:
        return role ?? 'Неизвестно';
    }
  }

  /// Проверка истек ли срок приглашения
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory Invitation.fromJson(Map<String, dynamic> json) {
    return Invitation(
      id: json['id'] as int,
      organizationId: json['organization_id'] as int,
      inviterId: json['inviter_id'] as int,
      token: json['token'] as String,
      type: json['type'] as String,
      role: json['role'] as String?,
      status: json['status'] as String,
      expiresAt: DateTime.parse(json['expires_at'].toString()),
      createdAt: DateTime.parse(json['created_at'].toString()),
      inviteUrl: json['invite_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'inviter_id': inviterId,
      'token': token,
      'type': type,
      'role': role,
      'status': status,
      'expires_at': expiresAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'invite_url': inviteUrl,
    };
  }

  @override
  String toString() {
    return 'Invitation(id: $id, role: $role, status: $status)';
  }
}
