import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../utils/app_icons.dart';
import '../repositories/diary_repository.dart';
import '../bloc/diary/diary_bloc.dart';
import '../bloc/diary/diary_event.dart';
import '../bloc/diary/diary_state.dart';

class EditDiaryEntryPage extends StatefulWidget {
  final DiaryEntry entry;
  final int diaryId;
  final int patientId;

  const EditDiaryEntryPage({
    super.key,
    required this.entry,
    required this.diaryId,
    required this.patientId,
  });
  static const String routeName = '/edit-diary-entry';

  @override
  State<EditDiaryEntryPage> createState() => _EditDiaryEntryPageState();
}

class _EditDiaryEntryPageState extends State<EditDiaryEntryPage> {
  late TextEditingController _valueController;
  late TextEditingController _notesController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.entry.recordedAt.toLocal();
    _selectedTime = TimeOfDay.fromDateTime(widget.entry.recordedAt.toLocal());
    _notesController = TextEditingController(text: widget.entry.notes ?? '');

    // Инициализируем значение в зависимости от типа
    final value = widget.entry.value;
    String initialValue = '';
    if (value is Map) {
      if (widget.entry.parameterKey == 'blood_pressure') {
        final systolic = value['systolic'] ?? value['sys'] ?? '';
        final diastolic = value['diastolic'] ?? value['dia'] ?? '';
        initialValue = '$systolic/$diastolic';
      } else if (value.containsKey('value')) {
        initialValue = value['value'].toString();
      } else {
        initialValue = value.toString();
      }
    } else {
      initialValue = value?.toString() ?? '';
    }
    _valueController = TextEditingController(text: initialValue);
  }

  @override
  void dispose() {
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _getIndicatorLabel(String key) {
    const labels = {
      'blood_pressure': 'Давление',
      'temperature': 'Температура',
      'pulse': 'Пульс',
      'saturation': 'Сатурация',
      'oxygen_saturation': 'Сатурация',
      'respiratory_rate': 'Частота дыхания',
      'diaper_change': 'Смена подгузников',
      'walk': 'Прогулка',
      'skin_moisturizing': 'Увлажнение кожи',
      'medication': 'Приём лекарств',
      'feeding': 'Кормление',
      'meal': 'Прием пищи',
      'fluid_intake': 'Выпито жидкости',
      'urine_output': 'Выделено мочи',
      'urine_color': 'Цвет мочи',
      'urine': 'Выделение мочи',
      'defecation': 'Дефекация',
      'hygiene': 'Гигиена',
      'cognitive_games': 'Когнитивные игры',
      'vitamins': 'Приём витаминов',
      'sleep': 'Сон',
      'pain_level': 'Уровень боли',
      'sugar_level': 'Уровень сахара',
      'blood_sugar': 'Уровень сахара',
      'weight': 'Вес',
    };
    return labels[key] ?? key;
  }

  void _saveEntry(BuildContext blocContext) {
    if (_valueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Пожалуйста, введите значение',
            style: GoogleFonts.firaSans(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Обрабатываем значение в зависимости от типа параметра
    dynamic processedValue = _valueController.text;
    if (widget.entry.parameterKey == 'blood_pressure' &&
        processedValue.contains('/')) {
      final parts = processedValue.split('/');
      if (parts.length == 2) {
        processedValue = {
          'systolic': int.tryParse(parts[0].trim()) ?? 0,
          'diastolic': int.tryParse(parts[1].trim()) ?? 0,
        };
      }
    } else {
      // Для других параметров оборачиваем в объект value
      processedValue = {'value': processedValue};
    }

    // Формируем дату и время
    final recordedAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Обновляем запись
    blocContext.read<DiaryBloc>().add(
          UpdateDiaryEntry(
            entryId: widget.entry.id,
            value: processedValue,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
            recordedAt: recordedAt,
          ),
        );
  }

  void _handleDiaryState(BuildContext context, DiaryState state) {
    if (state is DiaryLoaded || state is DiaryInitial) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Запись обновлена',
            style: GoogleFonts.firaSans(),
          ),
          backgroundColor: Colors.green,
        ),
      );
      // Возвращаемся назад
      context.pop();
    } else if (state is DiaryError) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.message,
            style: GoogleFonts.firaSans(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DiaryBloc, DiaryState>(
      listener: _handleDiaryState,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Image.asset(
              AppIcons.back,
              width: 24,
              height: 24,
              fit: BoxFit.contain,
            ),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Редактирование записи',
            style: GoogleFonts.firaSans(
              color: Colors.grey.shade900,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Заголовок с названием показателя
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppConfig.primaryColor,
                        AppConfig.primaryColor.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _getIndicatorLabel(widget.entry.parameterKey),
                    style: GoogleFonts.firaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                // Поле значения
                TextField(
                  controller: _valueController,
                  decoration: InputDecoration(
                    labelText: 'Значение',
                    hintText: 'Введите новое значение',
                    hintStyle: GoogleFonts.firaSans(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: GoogleFonts.firaSans(),
                ),
                const SizedBox(height: 16),
                // Поле заметок
                TextField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Заметки',
                    hintText: 'Добавьте заметку (необязательно)',
                    hintStyle: GoogleFonts.firaSans(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: GoogleFonts.firaSans(),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                // Дата и время
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('dd.MM.yyyy').format(_selectedDate),
                                style: GoogleFonts.firaSans(
                                  fontSize: 14,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              Icon(Icons.calendar_today,
                                  size: 20, color: Colors.grey.shade600),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime,
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedTime = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedTime.format(context),
                                style: GoogleFonts.firaSans(
                                  fontSize: 14,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              Icon(Icons.access_time,
                                  size: 20, color: Colors.grey.shade600),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Кнопки
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => context.pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Отмена',
                          style: GoogleFonts.firaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Builder(
                        builder: (blocContext) {
                          return ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () => _saveEntry(blocContext),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConfig.primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    'Сохранить',
                                    style: GoogleFonts.firaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

