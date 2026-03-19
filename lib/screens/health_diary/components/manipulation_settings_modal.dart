import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:healapp_mobile/core/logging/app_logger.dart';
import 'package:healapp_mobile/config/app_config.dart';
import 'package:healapp_mobile/bloc/route_sheet/route_sheet_cubit.dart';
import 'package:healapp_mobile/bloc/route_sheet/route_sheet_state.dart';
import 'package:healapp_mobile/repositories/employee_repository.dart';
import 'package:healapp_mobile/models/employee.dart';
import 'package:healapp_mobile/core/network/api_client.dart';

/// Модальное окно настроек манипуляции
class ManipulationSettingsModalContent extends StatefulWidget {
  final String manipulationName;
  final Function(bool shouldAdd) onSave;
  final TextEditingController timeFromController;
  final TextEditingController timeToController;
  final MaskTextInputFormatter timeMaskFormatter;
  final RouteSheetCubit routeSheetCubit;
  final bool isCustom;

  const ManipulationSettingsModalContent({
    super.key,
    required this.manipulationName,
    required this.onSave,
    required this.timeFromController,
    required this.timeToController,
    required this.timeMaskFormatter,
    required this.routeSheetCubit,
    required this.isCustom,
  });

  @override
  State<ManipulationSettingsModalContent> createState() =>
      _ManipulationSettingsModalContentState();
}

class _ManipulationSettingsModalContentState
    extends State<ManipulationSettingsModalContent> {
  final Set<int> _selectedDays = {}; // 0-6 где 0=ПН, 6=ВС
  Employee? _selectedEmployee;
  final List<String> selectedTimes = [];
  final TextEditingController timeFromController = TextEditingController();
  final TextEditingController timeToController = TextEditingController();
  final timeMaskFormatter = MaskTextInputFormatter(
    mask: '##:##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  static const _dayLabels = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];
  // API использует 0 = Воскресенье, 1 = Понедельник...
  static const _dayApiValues = [1, 2, 3, 4, 5, 6, 0];

  // Сотрудники
  List<Employee> _employees = [];
  bool _isLoadingEmployees = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoadingEmployees = true;
    });

    try {
      final repository = EmployeeRepository();
      final employees = await repository.getEmployees();

      if (mounted) {
        setState(() {
          _employees = employees;
          _isLoadingEmployees = false;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          _isLoadingEmployees = false;
        });
        // Показываем ошибку пользователю
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ошибка загрузки сотрудников: ${e.toString()}',
              style: GoogleFonts.firaSans(),
            ),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Повторить',
              textColor: Colors.white,
              onPressed: _loadEmployees,
            ),
          ),
        );
      }
    }
  }

  void _showEmployeeSelectionDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          // Подписываемся на обновления состояния родительского виджета
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Выберите сотрудника',
                      style: GoogleFonts.firaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isLoadingEmployees)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_employees.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Нет доступных сотрудников',
                          style: GoogleFonts.firaSans(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _loadEmployees();
                          },
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            'Обновить список',
                            style: GoogleFonts.firaSans(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConfig.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _employees.length,
                      itemBuilder: (context, index) {
                        final employee = _employees[index];
                        final isSelected = _selectedEmployee?.id == employee.id;
                        return ListTile(
                          leading: _buildEmployeeAvatar(employee),
                          title: Text(
                            _getEmployeeDisplayName(employee),
                            style: GoogleFonts.firaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            employee.roleDisplayName,
                            style: GoogleFonts.firaSans(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: AppConfig.primaryColor,
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedEmployee = employee;
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'owner':
        return Colors.purple;
      case 'admin':
        return Colors.blue;
      case 'doctor':
        return Colors.green;
      case 'caregiver':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Виджет аватара сотрудника для маршрутного листа
  Widget _buildEmployeeAvatar(Employee employee) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: _getRoleColor(employee.role).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: employee.avatarUrl != null && employee.avatarUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                ApiConfig.getFullUrl(employee.avatarUrl!),
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Text(
                      _getEmployeeInitials(employee),
                      style: GoogleFonts.firaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _getRoleColor(employee.role),
                      ),
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1,
                        valueColor: AlwaysStoppedAnimation(
                          _getRoleColor(employee.role),
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          : Center(
              child: Text(
                _getEmployeeInitials(employee),
                style: GoogleFonts.firaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _getRoleColor(employee.role),
                ),
              ),
            ),
    );
  }

  /// Получить отображаемое имя сотрудника
  String _getEmployeeDisplayName(Employee employee) {
    // Модель Employee уже правильно обрабатывает отображение:
    // - Для организаций (owner) показывает название организации из поля name
    // - Для врачей и сиделок показывает имя и фамилию
    return employee.fullName;
  }

  /// Получить инициалы сотрудника с учетом организации
  String _getEmployeeInitials(Employee employee) {
    // Для организаций (владельцев) используем инициалы из названия организации
    if (employee.isOrganization &&
        employee.name != null &&
        employee.name!.isNotEmpty) {
      final words = employee.name!.split(' ');
      if (words.length >= 2) {
        return '${words[0][0].toUpperCase()}${words[1][0].toUpperCase()}';
      } else if (words.isNotEmpty) {
        return words[0].length >= 2
            ? '${words[0][0].toUpperCase()}${words[0][1].toUpperCase()}'
            : words[0][0].toUpperCase();
      }
    }

    // Для врачей и сиделок используем инициалы из имени и фамилии
    final first = employee.firstName?.isNotEmpty == true
        ? employee.firstName![0].toUpperCase()
        : '';
    final last = employee.lastName?.isNotEmpty == true
        ? employee.lastName![0].toUpperCase()
        : '';

    if (first.isEmpty && last.isEmpty) {
      return '?';
    }
    return '$last$first';
  }

  @override
  void dispose() {
    timeFromController.dispose();
    timeToController.dispose();
    super.dispose();
  }

  void _addTimeSlot() {
    final timeFrom = timeFromController.text.trim();
    final timeTo = timeToController.text.trim();

    if (timeFrom.isNotEmpty && timeTo.isNotEmpty) {
      setState(() {
        selectedTimes.add('$timeFrom - $timeTo');
        timeFromController.clear();
        timeToController.clear();
      });
    }
  }

  void _removeTimeSlot(int index) {
    setState(() {
      selectedTimes.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Настройте\nманипуляцию',
                  style: GoogleFonts.firaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppConfig.primaryColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Manipulation name
                  Text(
                    widget.manipulationName,
                    style: GoogleFonts.firaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Employee selection
                  Text(
                    'Выберите сотрудника:',
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _showEmployeeSelectionDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedEmployee != null
                                    ? AppConfig.primaryColor
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                if (_selectedEmployee != null) ...[
                                  _buildEmployeeAvatar(_selectedEmployee!),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Text(
                                    _selectedEmployee != null
                                        ? _getEmployeeDisplayName(
                                            _selectedEmployee!,
                                          )
                                        : 'Выберите сотрудника',
                                    style: GoogleFonts.firaSans(
                                      fontSize: 14,
                                      color: _selectedEmployee != null
                                          ? Colors.grey.shade900
                                          : Colors.grey.shade500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          // Переход на страницу сотрудников для добавления
                          context.push('/employees');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Добавить',
                          style: GoogleFonts.firaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Date selection
                  Text(
                    'Дни недели:',
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(7, (index) {
                        final isSelected = _selectedDays.contains(index);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedDays.remove(index);
                              } else {
                                _selectedDays.add(index);
                              }
                            });
                          },
                          child: Container(
                            width: 42,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppConfig.primaryColor
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? null
                                  : Border.all(color: Colors.grey.shade300),
                            ),
                            child: Center(
                              child: Text(
                                _dayLabels[index],
                                style: GoogleFonts.firaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Time selection
                  Text(
                    'Выберите время',
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Selected times chips
                  if (selectedTimes.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedTimes.asMap().entries.map((entry) {
                        final index = entry.key;
                        final time = entry.value;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppConfig.primaryColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                time,
                                style: GoogleFonts.firaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _removeTimeSlot(index),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Time input fields
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: timeFromController,
                          inputFormatters: [timeMaskFormatter],
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            hintText: 'Время с',
                            hintStyle: GoogleFonts.firaSans(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          style: GoogleFonts.firaSans(
                            fontSize: 14,
                            color: Colors.grey.shade900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: timeToController,
                          inputFormatters: [timeMaskFormatter],
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            hintText: 'Время до',
                            hintStyle: GoogleFonts.firaSans(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          style: GoogleFonts.firaSans(
                            fontSize: 14,
                            color: Colors.grey.shade900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _addTimeSlot,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppConfig.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Bottom buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      // Валидация
                      if (_selectedDays.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Пожалуйста, выберите хотя бы один день',
                              style: GoogleFonts.firaSans(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (selectedTimes.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Пожалуйста, добавьте хотя бы один временной слот',
                              style: GoogleFonts.firaSans(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      try {
                        // Функция для нормализации формата времени (7:00 -> 07:00)
                        String normalizeTime(String time) {
                          final parts = time.trim().split(':');
                          if (parts.length != 2) return time;

                          final hour = parts[0].padLeft(2, '0');
                          final minute = parts[1].padLeft(2, '0');
                          return '$hour:$minute';
                        }

                        // Преобразуем selectedTimes в TimeRange
                        final timeRanges = selectedTimes.map((timeRange) {
                          final parts = timeRange.split(' - ');
                          return TimeRange(
                            start: normalizeTime(parts[0]),
                            end: normalizeTime(
                              parts.length > 1 ? parts[1] : parts[0],
                            ),
                          );
                        }).toList();

                        // Преобразуем выбранные дни в формат API
                        final apiDaysOfWeek = _selectedDays
                            .map((index) => _dayApiValues[index])
                            .toList();

                        // Создаём шаблон задачи через API
                        await widget.routeSheetCubit.createTemplate(
                          title: widget.manipulationName,
                          assignedTo: _selectedEmployee?.id,
                          daysOfWeek: apiDaysOfWeek,
                          timeRanges: timeRanges,
                          startDate: DateTime.now(),
                          type: widget.isCustom ? 'custom' : null,
                        );

                        // Перезагружаем список задач
                        await widget.routeSheetCubit.loadRouteSheet();

                        widget.onSave(true);

                        if (context.mounted) {
                          context.pop();

                          // Добавляем небольшую задержку перед показом SnackBar
                          // чтобы избежать конфликтов с навигацией
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Манипуляция успешно добавлена',
                                    style: GoogleFonts.firaSans(),
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          });
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Ошибка при создании манипуляции: $e',
                                style: GoogleFonts.firaSans(),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Сохранить',
                      style: GoogleFonts.firaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Отмена',
                      style: GoogleFonts.firaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
