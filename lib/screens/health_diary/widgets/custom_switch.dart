import 'package:flutter/material.dart';

import '../../../config/app_config.dart';

/// Кастомный переключатель в стиле приложения
class CustomSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;
  final double width;
  final double height;
  final Duration animationDuration;

  const CustomSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor = Colors.white,
    this.width = 48,
    this.height = 28,
    this.animationDuration = const Duration(milliseconds: 200),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor = activeColor ?? AppConfig.primaryColor;
    final effectiveInactiveColor = inactiveColor ?? Colors.grey.shade300;
    final thumbSize = height - 4;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: animationDuration,
        curve: Curves.easeInOut,
        width: width,
        height: height,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? effectiveActiveColor : effectiveInactiveColor,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(
            color: value ? effectiveActiveColor : Colors.grey.shade400,
            width: 1,
          ),
        ),
        child: AnimatedAlign(
          duration: animationDuration,
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: thumbSize,
            height: thumbSize,
            decoration: BoxDecoration(
              color: thumbColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
