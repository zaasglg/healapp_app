/// Вкладка дневника здоровья
///
/// Основная вкладка с показателями здоровья,
/// закреплёнными индикаторами и категориями.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../bloc/diary/diary_bloc.dart';
import '../../../bloc/diary/diary_state.dart';
import '../../../bloc/diary/diary_event.dart';
import '../../../config/app_config.dart';
import '../../../utils/health_diary/health_diary_utils.dart';
import '../widgets/indicators/indicators.dart';
import '../widgets/modals/modals.dart';

/// Вкладка дневника здоровья
class DiaryTab extends StatefulWidget {
  /// ID дневника
  final int diaryId;

  /// Является ли пользователь владельцем
  final bool isOwner;

  /// Callback при изменении данных
  final VoidCallback? onDataChanged;

  const DiaryTab({
    super.key,
    required this.diaryId,
    this.isOwner = true,
    this.onDataChanged,
  });

  @override
  State<DiaryTab> createState() => _DiaryTabState();
}

class _DiaryTabState extends State<DiaryTab> {
  // Состояние раскрытых категорий
  final Map<String, bool> _expandedCategories = {};

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiaryBloc, DiaryState>(
      builder: (context, state) {
        if (state is DiaryLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is DiaryError) {
          return _buildErrorState(state.message);
        }

        if (state is DiaryLoaded) {
          return _buildContent(state);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildContent(DiaryLoaded state) {
    final diary = state.diary;
    final entries = diary.entries;
    final pinnedIndicators = diary.pinnedParameters;
    final settings = diary.settings;
    final allIndicators = _normalizeIndicatorKeys(
      settings?['all_indicators'] ?? settings?['allIndicators'],
    );

    final careIndicators = allIndicators
        .where((e) => careIndicatorKeys.contains(e))
        .toList();
    final physicalIndicators = allIndicators
        .where((e) => physicalIndicatorKeys.contains(e))
        .toList();
    final excretionIndicators = allIndicators
        .where((e) => excretionIndicatorKeys.contains(e))
        .toList();
    final customIndicators = allIndicators
        .where(
          (e) =>
              !careIndicatorKeys.contains(e) &&
              !physicalIndicatorKeys.contains(e) &&
              !excretionIndicatorKeys.contains(e),
        )
        .toList();

    // Преобразуем закреплённые индикаторы
    final pinnedData = pinnedIndicators.map((indicator) {
      final key = indicator.key;
      final entry = entries.where((e) => e.parameterKey == key).firstOrNull;

      return PinnedIndicatorData(
        key: key,
        label: getIndicatorLabel(key),
        value: entry?.value,
        lastFillTime: entry?.recordedAt,
        isFilled: entry?.value != null,
      );
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        context.read<DiaryBloc>().add(LoadDiary(widget.diaryId));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Закреплённые показатели
            if (pinnedData.isNotEmpty) ...[
              PinnedIndicatorsSection(
                indicators: pinnedData,
                showSettings: widget.isOwner,
                onFill: (key, value) => _fillIndicator(key, value),
                onSettingsTap: () => _openPinnedSettings(),
              ),
              const SizedBox(height: 24),
            ],

            // Категории показателей
            Text(
              'Все показатели',
              style: GoogleFonts.firaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 12),

            // Категория ухода
            CategoryCard(
              title: 'Уход',
              indicators: careIndicators,
              fallbackIndicators: careIndicatorKeys,
              isExpanded: _expandedCategories['care'] ?? false,
              onToggle: () => _toggleCategory('care'),
              onIndicatorTap: (key, label) => _showIndicatorModal(key),
            ),
            const SizedBox(height: 12),

            // Физические показатели
            CategoryCard(
              title: 'Физические показатели',
              indicators: physicalIndicators,
              fallbackIndicators: physicalIndicatorKeys,
              isExpanded: _expandedCategories['physical'] ?? false,
              onToggle: () => _toggleCategory('physical'),
              onIndicatorTap: (key, label) => _showIndicatorModal(key),
            ),
            const SizedBox(height: 12),

            // Выделение мочи и кала
            CategoryCard(
              title: 'Выделение мочи и кала',
              indicators: excretionIndicators,
              fallbackIndicators: excretionIndicatorKeys,
              isExpanded: _expandedCategories['excretion'] ?? false,
              onToggle: () => _toggleCategory('excretion'),
              onIndicatorTap: (key, label) => _showIndicatorModal(key),
            ),
            if (customIndicators.isNotEmpty) ...[
              const SizedBox(height: 12),
              CategoryCard(
                title: 'Дополнительные показатели',
                indicators: customIndicators,
                fallbackIndicators: const [],
                isExpanded: _expandedCategories['custom'] ?? false,
                onToggle: () => _toggleCategory('custom'),
                onIndicatorTap: (key, label) => _showIndicatorModal(key),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Ошибка загрузки',
              style: GoogleFonts.firaSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.firaSans(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.read<DiaryBloc>().add(LoadDiary(widget.diaryId));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Повторить',
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleCategory(String category) {
    setState(() {
      _expandedCategories[category] = !(_expandedCategories[category] ?? false);
    });
  }

  List<String> _normalizeIndicatorKeys(dynamic rawIndicators) {
    if (rawIndicators == null) return [];

    if (rawIndicators is List) {
      return rawIndicators
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (rawIndicators is String) {
      final cleaned = rawIndicators.replaceAll('[', '').replaceAll(']', '');
      return cleaned
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return [];
  }

  Future<void> _fillIndicator(String key, dynamic value) async {
    // Преобразуем значение в строку для API
    final stringValue = value?.toString() ?? '';

    context.read<DiaryBloc>().add(
      AddDiaryEntry(
        diaryId: widget.diaryId,
        parameterKey: key,
        value: stringValue,
      ),
    );
    widget.onDataChanged?.call();
  }

  Future<void> _showIndicatorModal(String key) async {
    final paramType = getParameterType(key);
    final label = getIndicatorLabel(key);
    final description = getIndicatorDescription(key);
    final unit = getUnitForParameter(key);

    dynamic result;

    switch (paramType) {
      case 'boolean':
        result = await showBooleanModal(
          context: context,
          title: label,
          description: description,
        );
        break;

      case 'measurement':
        final measureResult = await showMeasurementModal(
          context: context,
          title: label,
          description: description,
          unit: unit,
          key: key,
        );
        result = measureResult?.value;
        break;

      case 'text':
        result = await showTextInputModal(
          context: context,
          title: label,
          description: description,
          hint: 'Введите информацию...',
        );
        break;

      case 'time_range':
        final timeResult = await showTimeRangeModal(
          context: context,
          title: label,
          description: description,
        );
        if (timeResult != null) {
          result = {
            'start':
                '${timeResult.startTime.hour.toString().padLeft(2, '0')}:${timeResult.startTime.minute.toString().padLeft(2, '0')}',
            'end':
                '${timeResult.endTime.hour.toString().padLeft(2, '0')}:${timeResult.endTime.minute.toString().padLeft(2, '0')}',
          };
        }
        break;

      case 'urine_color':
        result = await showUrineColorModal(context: context, title: label);
        break;

      case 'medication':
        final medResult = await showMedicationModal(
          context: context,
          title: label,
        );
        if (medResult != null) {
          result = {'name': medResult.name, 'dosage': medResult.dosage};
        }
        break;

      default:
        result = await showTextInputModal(
          context: context,
          title: label,
          description: description,
          hint: 'Введите значение...',
        );
    }

    if (result != null) {
      await _fillIndicator(key, result);
    }
  }

  void _openPinnedSettings() {
    // TODO: Открыть экран настройки закреплённых показателей
  }
}
