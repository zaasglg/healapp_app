/// Элемент списка с доступом
///
/// Компактный элемент для отображения сотрудника
/// в списке с доступом к дневнику.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/app_config.dart';

/// Элемент списка сотрудника с доступом
class AccessListItem extends StatelessWidget {
  /// Имя сотрудника
  final String name;

  /// URL аватара
  final String? avatarUrl;

  /// Роль сотрудника
  final String role;

  /// Является ли владельцем
  final bool isOwner;

  /// Callback при удалении
  final VoidCallback? onRemove;

  /// Показывать ли кнопку удаления
  final bool showRemoveButton;

  const AccessListItem({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.role,
    this.isOwner = false,
    this.onRemove,
    this.showRemoveButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Аватар
          CircleAvatar(
            radius: 20,
            backgroundColor: AppConfig.primaryColor.withOpacity(0.1),
            backgroundImage: avatarUrl != null
                ? NetworkImage(avatarUrl!)
                : null,
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.firaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppConfig.primaryColor,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),

          // Информация
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isOwner) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppConfig.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Владелец',
                          style: GoogleFonts.firaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppConfig.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  role,
                  style: GoogleFonts.firaSans(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Кнопка удаления
          if (showRemoveButton && !isOwner && onRemove != null)
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.close, color: Colors.red.shade400, size: 16),
              ),
            ),
        ],
      ),
    );
  }
}
