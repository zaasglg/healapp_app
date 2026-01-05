import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../config/app_config.dart';

/// Таб "История" для страницы дневника здоровья
class HistoryTab extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onDateChanged;

  const HistoryTab({
    super.key,
    required this.initialDate,
    required this.onDateChanged,
  });

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  late DateTime _selectedDate;
  bool _isDatePickerExpanded = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'НАЖМИТЕ, ЧТОБЫ ВЫБРАТЬ ДАТУ ИСТОРИИ ЗАПОЛНЕНИЯ',
              style: GoogleFonts.firaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            _buildDatePicker(),
            const SizedBox(height: 24),
            _buildMedicationsSection(),
            const SizedBox(height: 24),
            _buildReportSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    // Форматируем дату с заглавной первой буквой
    final formattedDate = DateFormat(
      "EEEE, d MMMM y'г'",
      'ru',
    ).format(_selectedDate);
    final capitalizedDate =
        formattedDate[0].toUpperCase() + formattedDate.substring(1);

    return InkWell(
      onTap: () {
        setState(() {
          _isDatePickerExpanded = !_isDatePickerExpanded;
        });
      },
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE5F4F7), Color(0xFFD0EDF2)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2B8A9E).withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              capitalizedDate,
              textAlign: TextAlign.center,
              style: GoogleFonts.firaSans(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A6B7C),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Отчёт будет построен за этот день',
              textAlign: TextAlign.center,
              style: GoogleFonts.firaSans(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6BC4D4),
              ),
            ),
            if (_isDatePickerExpanded) ...[
              const SizedBox(height: 16),
              _buildDaySelector(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    final daysInMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
    ).day;
    final selectedDayIndex = _selectedDate.day - 1;
    final initialOffset = (selectedDayIndex * 56.0) - 140;

    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        controller: ScrollController(
          initialScrollOffset: initialOffset > 0 ? initialOffset : 0,
        ),
        itemCount: daysInMonth,
        itemBuilder: (context, index) {
          final date = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            index + 1,
          );
          final isSelected = date.day == _selectedDate.day;
          final monthName = DateFormat('MMM', 'ru').format(date);

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
                _isDatePickerExpanded = false;
              });
              widget.onDateChanged(date);
            },
            child: Container(
              width: 48,
              margin: EdgeInsets.only(
                left: index == 0 ? 0 : 4,
                right: index == daysInMonth - 1 ? 0 : 4,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF5A5A5A)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF7A7A7A), width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    monthName,
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF5A5A5A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: GoogleFonts.firaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF5A5A5A),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMedicationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Принятые лекарства и витамины',
          style: GoogleFonts.firaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppConfig.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              'Нет записей за эту дату',
              style: GoogleFonts.firaSans(
                fontSize: 14,
                color: AppConfig.primaryColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Отчёт за сегодня',
          style: GoogleFonts.firaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppConfig.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildReportItem('СМЕНА ПОДГУЗНИКОВ', '122', '04:07'),
              const SizedBox(height: 16),
              _buildReportItem('ТЕМПЕРАТУРА', '2°C', '10:25'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportItem(String title, String value, String time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.firaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              Text(
                time,
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
