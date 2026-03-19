/// Модель пациента (подопечного)
class Patient {
  final int id;
  final int? creatorId;
  final int? organizationId;
  final String? firstName;
  final String? lastName;
  final String? middleName;
  final String? fullNameFromApi;
  final DateTime? birthDate;
  final String? gender;
  final double? weight;
  final double? height;
  final String? mobility;
  final String? address;
  final List<String>? diagnoses;
  final List<String>? neededServices;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Patient({
    required this.id,
    this.creatorId,
    this.organizationId,
    this.firstName,
    this.lastName,
    this.middleName,
    this.fullNameFromApi,
    this.birthDate,
    this.gender,
    this.weight,
    this.height,
    this.mobility,
    this.address,
    this.diagnoses,
    this.neededServices,
    this.createdAt,
    this.updatedAt,
  });

  /// Полное имя пациента
  String get fullName {
    final parts = <String>[];
    if (lastName != null && lastName!.isNotEmpty) parts.add(lastName!);
    if (firstName != null && firstName!.isNotEmpty) parts.add(firstName!);
    if (middleName != null && middleName!.isNotEmpty) parts.add(middleName!);
    if (parts.isNotEmpty) return parts.join(' ');
    if (fullNameFromApi != null && fullNameFromApi!.trim().isNotEmpty) {
      return fullNameFromApi!.trim();
    }
    return 'Без имени';
  }

  /// Краткое имя пациента в формате "Фамилия И.О."
  String get shortName {
    final safeLastName = lastName?.trim() ?? '';
    final safeFirstName = firstName?.trim() ?? '';
    final safeMiddleName = middleName?.trim() ?? '';

    // В приоритете составление из отдельных полей: "Фамилия И.О."
    if (safeLastName.isNotEmpty ||
        safeFirstName.isNotEmpty ||
        safeMiddleName.isNotEmpty) {
      final buffer = StringBuffer();

      if (safeLastName.isNotEmpty) {
        buffer.write(safeLastName);
      }
      if (safeFirstName.isNotEmpty) {
        if (buffer.length > 0) buffer.write(' ');
        buffer.write('${safeFirstName[0]}.');
      }
      if (safeMiddleName.isNotEmpty) {
        buffer.write('${safeMiddleName[0]}.');
      }

      final result = buffer.toString().trim();
      if (result.isNotEmpty) return result;
    }

    // Fallback: пробуем собрать формат из full_name от API.
    if (fullNameFromApi != null && fullNameFromApi!.trim().isNotEmpty) {
      final parts = fullNameFromApi!.trim().split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        final apiLastName = parts[0];
        final initials = StringBuffer();
        if (parts.length > 1 && parts[1].isNotEmpty) {
          initials.write('${parts[1][0]}.');
        }
        if (parts.length > 2 && parts[2].isNotEmpty) {
          initials.write('${parts[2][0]}.');
        }
        return initials.length > 0
            ? '$apiLastName ${initials.toString()}'
            : apiLastName;
      }
    }

    return 'Без имени';
  }

  /// Возраст пациента
  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      age--;
    }
    return age;
  }

  /// Пол на русском
  String get genderLabel {
    switch (gender) {
      case 'male':
        return 'Мужской';
      case 'female':
        return 'Женский';
      default:
        return 'Не указан';
    }
  }

  /// Мобильность на русском
  String get mobilityLabel {
    switch (mobility) {
      case 'walking':
        return 'Ходит';
      case 'sitting':
        return 'Сидит';
      case 'bedridden':
        return 'Лежит';
      default:
        return 'Не указана';
    }
  }

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] as int,
      creatorId: json['creator_id'] as int?,
      organizationId: json['organization_id'] as int?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      middleName: json['middle_name'] as String?,
      fullNameFromApi: json['full_name'] as String?,
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'] as String)
          : null,
      gender: json['gender'] as String?,
      weight: (json['weight'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      mobility: json['mobility'] as String?,
      address: json['address'] as String?,
      diagnoses: (json['diagnoses'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      neededServices: (json['needed_services'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creator_id': creatorId,
      'organization_id': organizationId,
      'first_name': firstName,
      'last_name': lastName,
      'middle_name': middleName,
      'full_name': fullNameFromApi,
      'birth_date': birthDate?.toIso8601String(),
      'gender': gender,
      'weight': weight,
      'height': height,
      'mobility': mobility,
      'address': address,
      'diagnoses': diagnoses,
      'needed_services': neededServices,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Patient(id: $id, name: $fullName, age: $age)';
  }
}
