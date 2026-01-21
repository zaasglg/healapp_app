/// Секция управления доступом
///
/// Отображает список сотрудников с доступом к дневнику
/// и позволяет управлять приглашениями.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/app_config.dart';

/// Модель данных сотрудника с доступом
class AccessEmployeeData {
  final int id;
  final String name;
  final String? avatarUrl;
  final String role;
  final bool isOwner;
  final DateTime? accessGrantedAt;

  AccessEmployeeData({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.role,
    this.isOwner = false,
    this.accessGrantedAt,
  });
}

/// Секция управления доступом к дневнику
class AccessManagementSection extends StatelessWidget {
  /// Список сотрудников с доступом
  final List<AccessEmployeeData> employees;

  /// Callback при добавлении сотрудника
  final VoidCallback? onAddEmployee;

  /// Callback при удалении сотрудника
  final Function(int employeeId)? onRemoveEmployee;

  /// Является ли текущий пользователь владельцем
  final bool isOwner;

  /// Заголовок секции
  final String title;

  const AccessManagementSection({
    super.key,
    required this.employees,
    this.onAddEmployee,
    this.onRemoveEmployee,
    this.isOwner = false,
    this.title = 'Управление доступом',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.firaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade900,
              ),
            ),
            if (isOwner && onAddEmployee != null)
              IconButton(
                onPressed: onAddEmployee,
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppConfig.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person_add_outlined,
                    color: AppConfig.primaryColor,
                    size: 20,
                  ),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),

        const SizedBox(height: 16),

        // Список сотрудников
        if (employees.isEmpty)
          _buildEmptyState()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: employees.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final employee = employees[index];
              return _buildEmployeeItem(context, employee);
            },
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.group_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'Нет сотрудников с доступом',
            style: GoogleFonts.firaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Добавьте сотрудников для совместной работы',
            style: GoogleFonts.firaSans(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeItem(BuildContext context, AccessEmployeeData employee) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Аватар
          CircleAvatar(
            radius: 22,
            backgroundColor: AppConfig.primaryColor.withOpacity(0.1),
            backgroundImage: employee.avatarUrl != null
                ? NetworkImage(employee.avatarUrl!)
                : null,
            child: employee.avatarUrl == null
                ? Text(
                    employee.name.isNotEmpty
                        ? employee.name[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.firaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppConfig.primaryColor,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Информация
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        employee.name,
                        style: GoogleFonts.firaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (employee.isOwner) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppConfig.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Владелец',
                          style: GoogleFonts.firaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppConfig.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  employee.role,
                  style: GoogleFonts.firaSans(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Кнопка удаления
          if (isOwner && !employee.isOwner && onRemoveEmployee != null)
            IconButton(
              onPressed: () => onRemoveEmployee!(employee.id),
              icon: Icon(Icons.close, color: Colors.grey.shade400, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
