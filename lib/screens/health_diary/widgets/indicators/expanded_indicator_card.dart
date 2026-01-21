/// Расширенная карточка индикатора
///
/// Отображает индикатор с возможностью заполнения значения.
/// Используется в развёрнутом виде при раскрытии секции.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/app_config.dart';
import '../../../../utils/health_diary/indicator_utils.dart';
import '../modals/modals.dart';

/// Расширенная карточка индикатора с таймером и заполнением
class ExpandedIndicatorCard extends StatefulWidget {
  /// Ключ показателя (например, 'temperature')
  final String indicatorKey;

  /// Текущее значение (если есть)
  final dynamic currentValue;

  /// Время последнего заполнения (для таймера)
  final DateTime? lastFillTime;

  /// Callback при заполнении показателя
  final Function(dynamic value, String displayText)? onFill;

  /// Уже заполнен ли показатель
  final bool isFilled;

  const ExpandedIndicatorCard({
    super.key,
    required this.indicatorKey,
    this.currentValue,
    this.lastFillTime,
    this.onFill,
    this.isFilled = false,
  });

  @override
  State<ExpandedIndicatorCard> createState() => _ExpandedIndicatorCardState();
}

class _ExpandedIndicatorCardState extends State<ExpandedIndicatorCard> {
  Timer? _timer;
  String _displayTime = '--:--';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  void _updateTime() {
    if (!mounted) return;
    final now = DateTime.now();
    setState(() {
      _displayTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
  }

  String get _iconPath {
    final key = widget.indicatorKey;
    // Маппинг ключей на файлы иконок
    final iconMap = {
      'temperature': 'temperature.svg',
      'blood_pressure': 'blood_pressure.svg',
      'heart_rate': 'heart_rate.svg',
      'weight': 'weight.svg',
      'oxygen_saturation': 'oxygen.svg',
      'blood_glucose': 'blood_glucose.svg',
      'sleep': 'sleep.svg',
      'defecation': 'defecation.svg',
      'urination': 'urination.svg',
      'urine_color': 'urine_color.svg',
      'feeding': 'feeding.svg',
      'medication_taken': 'medication.svg',
      'physical_activity': 'physical_activity.svg',
      'walk': 'walk.svg',
      'cognitive_games': 'cognitive.svg',
      'socializing': 'social.svg',
      'hobbies': 'hobbies.svg',
      'fall': 'fall.svg',
      'mood': 'mood.svg',
      'pain': 'pain.svg',
      'fatigue': 'fatigue.svg',
      'swelling': 'swelling.svg',
      'allergic_reaction': 'allergy.svg',
      'skin_condition': 'skin.svg',
      'consciousness': 'consciousness.svg',
    };
    final iconName = iconMap[key] ?? 'default_indicator.svg';
    return 'assets/icons/categories/$iconName';
  }

  @override
  Widget build(BuildContext context) {
    final label = getIndicatorLabel(widget.indicatorKey);
    final unit = getUnitForParameter(widget.indicatorKey);
    final description = getIndicatorDescription(widget.indicatorKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок с иконкой
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppConfig.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    _iconPath,
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                      AppConfig.primaryColor,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.firaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: GoogleFonts.firaSans(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Время
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _displayTime,
                      style: GoogleFonts.firaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Текущее значение или кнопка заполнения
          if (widget.isFilled && widget.currentValue != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConfig.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppConfig.primaryColor.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppConfig.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatValue(widget.currentValue, widget.indicatorKey),
                      style: GoogleFonts.firaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  Text(
                    unit,
                    style: GoogleFonts.firaSans(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showInputModal(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConfig.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Заполнить',
                  style: GoogleFonts.firaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showInputModal() async {
    final key = widget.indicatorKey;
    final label = getIndicatorLabel(key);
    final unit = getUnitForParameter(key);
    final description = getIndicatorDescription(key);
    final paramType = getParameterType(key);

    dynamic result;
    String displayText = '';

    switch (paramType) {
      case 'boolean':
        final boolResult = await showBooleanModal(
          context: context,
          title: label,
          description: description,
        );
        if (boolResult != null) {
          result = boolResult;
          displayText = boolResult ? 'Было' : 'Не было';
        }
        break;

      case 'measurement':
        final measureResult = await showMeasurementModal(
          context: context,
          title: label,
          description: description,
          unit: unit,
          key: key,
        );
        if (measureResult != null) {
          result = measureResult.value;
          displayText = measureResult.displayText;
        }
        break;

      case 'text':
        final textResult = await showTextInputModal(
          context: context,
          title: label,
          description: description,
          hint: 'Введите информацию...',
        );
        if (textResult != null) {
          result = textResult;
          displayText = textResult;
        }
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
          displayText = timeResult.formattedRange;
        }
        break;

      case 'urine_color':
        final colorResult = await showUrineColorModal(
          context: context,
          title: label,
        );
        if (colorResult != null) {
          result = colorResult;
          displayText = colorResult;
        }
        break;

      case 'medication':
        final medResult = await showMedicationModal(
          context: context,
          title: label,
        );
        if (medResult != null) {
          result = {'name': medResult.name, 'dosage': medResult.dosage};
          displayText = medResult.formatted;
        }
        break;

      case 'time':
        final timeResult = await showTimePickerModal(
          context: context,
          title: label,
          description: description,
        );
        if (timeResult != null) {
          result =
              '${timeResult.hour.toString().padLeft(2, '0')}:${timeResult.minute.toString().padLeft(2, '0')}';
          displayText = timeResult.format(context);
        }
        break;

      default:
        // По умолчанию показываем текстовый ввод
        final textResult = await showTextInputModal(
          context: context,
          title: label,
          description: description,
          hint: 'Введите значение...',
        );
        if (textResult != null) {
          result = textResult;
          displayText = textResult;
        }
    }

    if (result != null && widget.onFill != null) {
      widget.onFill!(result, displayText);
    }
  }

  /// Форматирует значение для отображения
  String _formatValue(dynamic value, String parameterKey) {
    if (value == null) return '—';

    // Обработка булевых значений
    if (value is bool) {
      return value ? 'Было' : 'Не было';
    }

    // Обработка числовых булевых представлений (1/0)
    if (value is num) {
      if (value == 1) return 'Было';
      if (value == 0) return 'Не было';
      return value.toString();
    }

    // Обработка Map (например blood_pressure)
    if (value is Map) {
      if (parameterKey == 'blood_pressure') {
        dynamic bpValue = value;
        // Если значение вложено в {value: {...}}, извлекаем его
        if (bpValue.containsKey('value') && bpValue['value'] is Map) {
          bpValue = bpValue['value'];
        }
        final systolic = bpValue['systolic'] ?? bpValue['sys'] ?? 0;
        final diastolic = bpValue['diastolic'] ?? bpValue['dia'] ?? 0;
        return '$systolic/$diastolic';
      }
      if (value.containsKey('value')) {
        final innerValue = value['value'];
        if (innerValue is bool) {
          return innerValue ? 'Было' : 'Не было';
        }
        return innerValue?.toString() ?? '—';
      }
      return value.values.map((v) => v.toString()).join(', ');
    }

    // Обработка строк "true"/"false"
    if (value is String) {
      final lowerValue = value.toLowerCase();
      if (lowerValue == 'true') return 'Было';
      if (lowerValue == 'false') return 'Не было';
    }

    return value.toString();
  }
}
