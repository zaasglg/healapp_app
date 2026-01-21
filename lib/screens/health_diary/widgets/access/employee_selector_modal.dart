/// Модальное окно выбора сотрудника
///
/// Используется для выбора сотрудника при предоставлении доступа.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/app_config.dart';

/// Модель сотрудника для выбора
class SelectableEmployee {
  final int id;
  final String name;
  final String? avatarUrl;
  final String role;
  final bool hasAccess;

  SelectableEmployee({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.role,
    this.hasAccess = false,
  });
}

/// Показать модальное окно выбора сотрудника
Future<SelectableEmployee?> showEmployeeSelectorModal({
  required BuildContext context,
  required List<SelectableEmployee> employees,
  String title = 'Выберите сотрудника',
}) async {
  return showModalBottomSheet<SelectableEmployee>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Ручка
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Заголовок
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.firaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Список сотрудников
            Expanded(
              child: employees.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: employees.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final employee = employees[index];
                        return _EmployeeListItem(
                          employee: employee,
                          onTap: employee.hasAccess
                              ? null
                              : () => Navigator.pop(ctx, employee),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildEmptyState() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.person_search_outlined,
          size: 64,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 16),
        Text(
          'Нет доступных сотрудников',
          style: GoogleFonts.firaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    ),
  );
}

class _EmployeeListItem extends StatelessWidget {
  final SelectableEmployee employee;
  final VoidCallback? onTap;

  const _EmployeeListItem({required this.employee, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDisabled = employee.hasAccess;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
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
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppConfig.primaryColor,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.name,
                        style: GoogleFonts.firaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        employee.role,
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDisabled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Есть доступ',
                      style: GoogleFonts.firaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.green,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.add_circle_outline,
                    color: AppConfig.primaryColor,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
