import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../repositories/alarm_repository.dart';

/// Данные нового будильника для передачи в callback
class AlarmFormData {
  final int diaryId;
  final String name;
  final AlarmType type;
  final List<int> daysOfWeek;
  final List<String> times;
  final String? dosage;
  final String? notes;

  const AlarmFormData({
    required this.diaryId,
    required this.name,
    required this.type,
    required this.daysOfWeek,
    required this.times,
    this.dosage,
    this.notes,
  });
}

/// Диалог для создания/редактирования будильника
class AlarmDialog extends StatefulWidget {
  final int diaryId;
  final void Function(AlarmFormData alarm) onSave;
  final Alarm? alarm; // Для редактирования
  final void Function(int alarmId, AlarmFormData data)? onUpdate;

  const AlarmDialog({
    super.key,
    required this.diaryId,
    required this.onSave,
    this.alarm,
    this.onUpdate,
  });

  @override
  State<AlarmDialog> createState() => _AlarmDialogState();
}

class _AlarmDialogState extends State<AlarmDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isVitamin = false; // false = Medicine, true = Vitamin
  final Set<int> _selectedDays = {};
  final List<TimeOfDay> _selectedTimes = [];
  final Color _activeColor = const Color(0xFF5AB6C3);
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Если есть будильник для редактирования - заполняем поля
    if (widget.alarm != null) {
      final alarm = widget.alarm!;
      _nameController.text = alarm.name;
      _isVitamin = alarm.type == AlarmType.vitamin;
      _selectedDays.addAll(alarm.daysOfWeek);
      _dosageController.text = alarm.dosage ?? '';
      _notesController.text = alarm.notes ?? '';
      // Преобразуем строки времени в TimeOfDay
      for (final timeStr in alarm.times) {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          _selectedTimes.add(
            TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool _validate() {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Введите название');
      return false;
    }
    if (_selectedDays.isEmpty) {
      setState(() => _errorMessage = 'Выберите хотя бы один день недели');
      return false;
    }
    if (_selectedTimes.isEmpty) {
      setState(() => _errorMessage = 'Добавьте хотя бы одно время');
      return false;
    }
    setState(() => _errorMessage = null);
    return true;
  }

  void _save() {
    if (!_validate()) return;

    final times = _selectedTimes.map((time) {
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }).toList();

    final formData = AlarmFormData(
      diaryId: widget.diaryId,
      name: _nameController.text.trim(),
      type: _isVitamin ? AlarmType.vitamin : AlarmType.medicine,
      daysOfWeek: _selectedDays.toList()..sort(),
      times: times,
      dosage: _dosageController.text.trim().isEmpty
          ? null
          : _dosageController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    // Если редактирование - вызываем onUpdate, иначе onSave
    if (widget.alarm != null && widget.onUpdate != null) {
      widget.onUpdate!(widget.alarm!.id, formData);
    } else {
      widget.onSave(formData);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.alarm != null ? 'Редактирование' : 'Новый будильник',
                style: GoogleFonts.firaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _activeColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.firaSans(
                      color: Colors.red.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _buildTextField(
                controller: _nameController,
                hintText: 'Название препарата',
                isPrimary: true,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _dosageController,
                hintText: 'Дозировка (напр. "1 таблетка")',
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _notesController,
                hintText: 'Заметки (напр. "После еды")',
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTypeButton(
                      'Лекарство',
                      !_isVitamin,
                      () => setState(() => _isVitamin = false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTypeButton(
                      'Витамин',
                      _isVitamin,
                      () => setState(() => _isVitamin = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Дни недели:',
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildDayButton('ПН', 1),
                  _buildDayButton('ВТ', 2),
                  _buildDayButton('СР', 3),
                  _buildDayButton('ЧТ', 4),
                  _buildDayButton('ПТ', 5),
                  _buildDayButton('СБ', 6),
                  _buildDayButton('ВС', 7),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Время (не более 4):',
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildTimeSection(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _activeColor,
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
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFAAB2BA),
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
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool isPrimary = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.firaSans(color: Colors.grey.shade400),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isPrimary
                ? _activeColor.withOpacity(0.5)
                : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _activeColor, width: 2),
        ),
      ),
      style: GoogleFonts.firaSans(color: Colors.grey.shade900),
    );
  }

  Widget _buildTimeSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Add time button
        if (_selectedTimes.length < 4)
          InkWell(
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
                builder: (context, child) {
                  return MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(alwaysUse24HourFormat: true),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: _activeColor,
                          onPrimary: Colors.white,
                          onSurface: Colors.grey.shade900,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                },
              );
              if (time != null) {
                setState(() {
                  // Avoid duplicates
                  if (!_selectedTimes.any(
                    (t) => t.hour == time.hour && t.minute == time.minute,
                  )) {
                    _selectedTimes.add(time);
                    _selectedTimes.sort(
                      (a, b) => (a.hour * 60 + a.minute).compareTo(
                        b.hour * 60 + b.minute,
                      ),
                    );
                  }
                });
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _activeColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _activeColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 24),
            ),
          ),
        ..._selectedTimes.map((time) {
          final timeStr =
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
          return Container(
            padding: const EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: GoogleFonts.firaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedTimes.remove(time);
                    });
                  },
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTypeButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _activeColor : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.firaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
      ),
    );
  }

  Widget _buildDayButton(String label, int value) {
    final isSelected = _selectedDays.contains(value);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedDays.remove(value);
          } else {
            _selectedDays.add(value);
          }
        });
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? _activeColor : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.firaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
        ),
      ),
    );
  }
}
