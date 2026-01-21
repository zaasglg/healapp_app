import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../bloc/route_sheet/route_sheet_cubit.dart';
import '../../../bloc/route_sheet/route_sheet_state.dart';
import '../../../config/app_config.dart';
import '../../../repositories/employee_repository.dart';
import '../widgets/modals/time_picker_modal.dart';

/// Диалог создания шаблона задачи для маршрутного листа
class CreateTaskTemplateDialog extends StatefulWidget {
  final String taskTitle;
  final String? relatedDiaryKey;

  const CreateTaskTemplateDialog({
    super.key,
    required this.taskTitle,
    this.relatedDiaryKey,
  });

  @override
  State<CreateTaskTemplateDialog> createState() =>
      _CreateTaskTemplateDialogState();
}

class _CreateTaskTemplateDialogState extends State<CreateTaskTemplateDialog> {
  final Set<int> _selectedDays = {};
  final List<String> _timeRanges = [];
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  bool _isLoading = false;

  // Состояние для сотрудников
  List<Employee> _employees = [];
  Employee? _selectedEmployee;
  bool _isLoadingEmployees = true;

  static const _dayLabels = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];
  // API использует 0 = Воскресенье, 1 = Понедельник...
  static const _dayApiValues = [1, 2, 3, 4, 5, 6, 0];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final repository = EmployeeRepository();
      final employees = await repository.getEmployees();
      if (mounted) {
        setState(() {
          _employees = employees;
          _isLoadingEmployees = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingEmployees = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTaskTitle(),
                      const SizedBox(height: 24),
                      _buildEmployeeSelector(),
                      const SizedBox(height: 24),
                      _buildDaysSelector(),
                      const SizedBox(height: 24),
                      _buildTimeRangesSection(),
                    ],
                  ),
                ),
              ),
              _buildBottomButton(),
            ],
          ),
        ),
        // Overlay loader
        if (_isLoading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Добавление задачи...',
                        style: GoogleFonts.firaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmployeeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Назначить сотруднику',
          style: GoogleFonts.firaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingEmployees)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_employees.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'Нет доступных сотрудников',
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          )
        else
          DropdownButtonFormField<Employee?>(
            value: _selectedEmployee,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppConfig.primaryColor),
              ),
            ),
            hint: Text(
              'Выберите сотрудника (необязательно)',
              style: GoogleFonts.firaSans(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            items: [
              DropdownMenuItem<Employee?>(
                value: null,
                child: Text(
                  'Не назначать',
                  style: GoogleFonts.firaSans(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              ..._employees.map((employee) {
                return DropdownMenuItem<Employee?>(
                  value: employee,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: _getRoleColor(employee.role),
                        child: Text(
                          employee.fullName.isNotEmpty
                              ? employee.fullName[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.firaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              employee.fullName,
                              style: GoogleFonts.firaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade900,
                              ),
                            ),
                            Text(
                              employee.roleDisplayName,
                              style: GoogleFonts.firaSans(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            onChanged: (value) {
              setState(() {
                _selectedEmployee = value;
              });
            },
            isExpanded: true,
          ),
      ],
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Настройка задачи',
            style: GoogleFonts.firaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppConfig.primaryColor,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTitle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConfig.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.task_alt, color: AppConfig.primaryColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.taskTitle,
              style: GoogleFonts.firaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Выберите дни недели',
          style: GoogleFonts.firaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppConfig.primaryColor
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? null
                      : Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Text(
                    _dayLabels[index],
                    style: GoogleFonts.firaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              setState(() {
                if (_selectedDays.length == 7) {
                  _selectedDays.clear();
                } else {
                  _selectedDays.addAll([0, 1, 2, 3, 4, 5, 6]);
                }
              });
            },
            child: Text(
              _selectedDays.length == 7 ? 'Снять все' : 'Выбрать все',
              style: GoogleFonts.firaSans(
                fontSize: 12,
                color: AppConfig.primaryColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRangesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Время выполнения',
          style: GoogleFonts.firaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        // Added time ranges
        ..._timeRanges.asMap().entries.map((entry) {
          final index = entry.key;
          final timeRange = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppConfig.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: AppConfig.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  timeRange,
                  style: GoogleFonts.firaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade400,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _timeRanges.removeAt(index);
                    });
                  },
                ),
              ],
            ),
          );
        }),
        // Add new time range
        Row(
          children: [
            Expanded(
              child: _buildTimeField(
                controller: _startTimeController,
                hint: 'Начало',
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '—',
                style: GoogleFonts.firaSans(
                  fontSize: 20,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
            Expanded(
              child: _buildTimeField(
                controller: _endTimeController,
                hint: 'Конец',
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _addTimeRange,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppConfig.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeField({
    required TextEditingController controller,
    required String hint,
  }) {
    return GestureDetector(
      onTap: () => _selectTime(controller),
      child: AbsorbPointer(
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.firaSans(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            suffixIcon: Icon(
              Icons.access_time,
              color: Colors.grey.shade600,
              size: 20,
            ),
          ),
          style: GoogleFonts.firaSans(
            fontSize: 14,
            color: Colors.grey.shade900,
          ),
        ),
      ),
    );
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final time = await showTimePickerModal(
      context: context,
      title: 'Выберите время',
      description: controller == _startTimeController
          ? 'Время начала выполнения задачи'
          : 'Время окончания выполнения задачи',
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      controller.text =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  void _addTimeRange() {
    if (_startTimeController.text.isEmpty || _endTimeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Укажите время начала и окончания',
            style: GoogleFonts.firaSans(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _timeRanges.add(
        '${_startTimeController.text} - ${_endTimeController.text}',
      );
      _startTimeController.clear();
      _endTimeController.clear();
    });
  }

  Widget _buildBottomButton() {
    return Container(
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
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _saveTemplate,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConfig.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Сохранить',
                  style: GoogleFonts.firaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _saveTemplate() async {
    // Validation
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Выберите хотя бы один день',
            style: GoogleFonts.firaSans(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_timeRanges.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Добавьте хотя бы одно время',
            style: GoogleFonts.firaSans(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final routeSheetCubit = context.read<RouteSheetCubit>();

      // Convert days to API format
      final apiDaysOfWeek = _selectedDays
          .map((index) => _dayApiValues[index])
          .toList();

      // Convert time ranges to TimeRange objects
      final timeRanges = _timeRanges.map((range) {
        final parts = range.split(' - ');
        return TimeRange(
          start: parts[0],
          end: parts.length > 1 ? parts[1] : parts[0],
        );
      }).toList();

      await routeSheetCubit.createTemplate(
        title: widget.taskTitle,
        assignedTo: _selectedEmployee?.id,
        daysOfWeek: apiDaysOfWeek,
        timeRanges: timeRanges,
        startDate: DateTime.now(),
        relatedDiaryKey: widget.relatedDiaryKey,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Задача "${widget.taskTitle}" добавлена',
              style: GoogleFonts.firaSans(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e', style: GoogleFonts.firaSans()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// Показать диалог создания шаблона задачи
Future<bool?> showCreateTaskTemplateDialog({
  required BuildContext context,
  required String taskTitle,
  String? relatedDiaryKey,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: context.read<RouteSheetCubit>(),
      child: CreateTaskTemplateDialog(
        taskTitle: taskTitle,
        relatedDiaryKey: relatedDiaryKey,
      ),
    ),
  );
}
