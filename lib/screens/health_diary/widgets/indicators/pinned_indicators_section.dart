/// Секция закреплённых показателей
///
/// Отображает список закреплённых показателей с возможностью
/// раскрытия/сворачивания и заполнения каждого показателя.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/app_config.dart';
import 'indicator_card.dart';
import 'expanded_indicator_card.dart';

/// Модель закреплённого показателя
class PinnedIndicatorData {
  final String key;
  final String label;
  final dynamic value;
  final DateTime? lastFillTime;
  final bool isFilled;

  PinnedIndicatorData({
    required this.key,
    required this.label,
    this.value,
    this.lastFillTime,
    this.isFilled = false,
  });
}

/// Секция закреплённых показателей
class PinnedIndicatorsSection extends StatefulWidget {
  /// Список закреплённых показателей
  final List<PinnedIndicatorData> indicators;

  /// Callback при заполнении показателя
  final Function(String key, dynamic value)? onFill;

  /// Callback при нажатии на настройку
  final VoidCallback? onSettingsTap;

  /// Показывать ли кнопку настроек
  final bool showSettings;

  /// Заголовок секции
  final String title;

  const PinnedIndicatorsSection({
    super.key,
    required this.indicators,
    this.onFill,
    this.onSettingsTap,
    this.showSettings = true,
    this.title = 'Закреплённые показатели',
  });

  @override
  State<PinnedIndicatorsSection> createState() =>
      _PinnedIndicatorsSectionState();
}

class _PinnedIndicatorsSectionState extends State<PinnedIndicatorsSection>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.indicators.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок секции
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: GoogleFonts.firaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                ),
              ),
              Row(
                children: [
                  if (widget.showSettings)
                    IconButton(
                      onPressed: widget.onSettingsTap,
                      icon: Icon(
                        Icons.settings_outlined,
                        color: Colors.grey.shade600,
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _toggleExpand,
                    child: AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.grey.shade600,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Свёрнутый вид - горизонтальный скролл
        AnimatedCrossFade(
          firstChild: SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.indicators.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final indicator = widget.indicators[index];
                return IndicatorCard(
                  name: indicator.label,
                  value: indicator.value?.toString(),
                  displayTime: _formatLastFillTime(indicator.lastFillTime),
                  onFillTap: () => _showQuickFillModal(indicator),
                );
              },
            ),
          ),
          secondChild: Column(
            children: widget.indicators.map((indicator) {
              return ExpandedIndicatorCard(
                indicatorKey: indicator.key,
                currentValue: indicator.value,
                lastFillTime: indicator.lastFillTime,
                isFilled: indicator.isFilled,
                onFill: (value, displayText) {
                  widget.onFill?.call(indicator.key, value);
                },
              );
            }).toList(),
          ),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
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
          Icon(Icons.push_pin_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'Нет закреплённых показателей',
            style: GoogleFonts.firaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Закрепите показатели для быстрого доступа',
            style: GoogleFonts.firaSans(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          if (widget.showSettings) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: widget.onSettingsTap,
              icon: Icon(Icons.add, color: AppConfig.primaryColor),
              label: Text(
                'Настроить',
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppConfig.primaryColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showQuickFillModal(PinnedIndicatorData indicator) {
    // При клике на свёрнутую карточку - раскрываем секцию
    if (!_isExpanded) {
      _toggleExpand();
    }
  }

  String _formatLastFillTime(DateTime? lastFillTime) {
    if (lastFillTime == null) {
      return 'Не заполнено';
    }

    final now = DateTime.now();
    final diff = now.difference(lastFillTime);

    if (diff.inMinutes < 1) {
      return 'Только что';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} мин назад';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} ч назад';
    } else {
      return '${diff.inDays} дн назад';
    }
  }
}
