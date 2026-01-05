import 'package:flutter/material.dart';

import '../../../repositories/diary_repository.dart';
import 'indicator_card.dart';
import 'expanded_indicator_card.dart';

/// Секция закрепленных показателей с анимацией
class PinnedIndicatorsSection extends StatelessWidget {
  final List<PinnedParameter> pinnedParameters;
  final AnimationController animationController;
  final Animation<double> expandAnimation;
  final int? selectedIndicatorIndex;
  final int? animatingFromIndex;
  final Function(int) onIndicatorSelected;
  final VoidCallback onIndicatorClosed;
  final Map<int, TextEditingController> measurementControllers;
  final Map<int, TextEditingController> timeControllers;
  final Map<int, int> fillCounts;
  final Function(int, int) onFillCountChanged;

  const PinnedIndicatorsSection({
    super.key,
    required this.pinnedParameters,
    required this.animationController,
    required this.expandAnimation,
    required this.selectedIndicatorIndex,
    required this.animatingFromIndex,
    required this.onIndicatorSelected,
    required this.onIndicatorClosed,
    required this.measurementControllers,
    required this.timeControllers,
    required this.fillCounts,
    required this.onFillCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        final animValue = expandAnimation.value;
        final isExpanding = selectedIndicatorIndex != null;
        final isClosing = !isExpanding && animatingFromIndex != null;

        // During animation, show both states with Stack
        if (animatingFromIndex != null || (isExpanding && animValue < 1.0)) {
          return Stack(
            children: [
              // Cards list (fading out when expanding, fading in when closing)
              if (pinnedParameters.isNotEmpty)
                Opacity(
                  opacity: isExpanding
                      ? (1.0 - animValue).clamp(0.0, 1.0)
                      : animValue.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(
                      isExpanding ? animValue * 50 : (1.0 - animValue) * 50,
                      0,
                    ),
                    child: _buildIndicatorCards(),
                  ),
                ),
              // Expanded card
              if (isExpanding || isClosing)
                Opacity(
                  opacity: isExpanding
                      ? animValue.clamp(0.0, 1.0)
                      : (1.0 - animValue).clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(
                      isExpanding ? -50 * (1.0 - animValue) : -50 * animValue,
                      0,
                    ),
                    child: Transform.scale(
                      scale: isExpanding
                          ? 0.85 + (animValue * 0.15)
                          : 1.0 - (animValue * 0.15),
                      alignment: Alignment.centerLeft,
                      child: ExpandedIndicatorCard(
                        index: isExpanding
                            ? selectedIndicatorIndex!
                            : animatingFromIndex!,
                        pinnedParameters: pinnedParameters,
                        measurementController:
                            measurementControllers[isExpanding
                                ? selectedIndicatorIndex!
                                : animatingFromIndex!],
                        timeController:
                            timeControllers[isExpanding
                                ? selectedIndicatorIndex!
                                : animatingFromIndex!],
                        fillCount:
                            fillCounts[isExpanding
                                ? selectedIndicatorIndex!
                                : animatingFromIndex!] ??
                            0,
                        onClose: onIndicatorClosed,
                        onFillCountChanged: onFillCountChanged,
                      ),
                    ),
                  ),
                ),
            ],
          );
        }

        // Static states (no animation in progress)
        if (selectedIndicatorIndex != null) {
          return ExpandedIndicatorCard(
            index: selectedIndicatorIndex!,
            pinnedParameters: pinnedParameters,
            measurementController:
                measurementControllers[selectedIndicatorIndex!],
            timeController: timeControllers[selectedIndicatorIndex!],
            fillCount: fillCounts[selectedIndicatorIndex!] ?? 0,
            onClose: onIndicatorClosed,
            onFillCountChanged: onFillCountChanged,
          );
        } else if (pinnedParameters.isNotEmpty) {
          return _buildIndicatorCards();
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildIndicatorCards() {
    return Row(
      children: List.generate(pinnedParameters.length, (index) {
        final param = pinnedParameters[index];
        return Expanded(
          child: IndicatorCard(
            parameter: param,
            index: index,
            isLast: index == pinnedParameters.length - 1,
            onTap: () => onIndicatorSelected(index),
          ),
        );
      }),
    );
  }
}
