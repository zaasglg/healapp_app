import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../../../repositories/diary_repository.dart';
import '../utils/indicator_utils.dart';
import 'dashed_circle_painter.dart';

/// Карточка показателя в развёрнутом виде с возможностью ввода данных
class ExpandedIndicatorCard extends StatelessWidget {
  final int index;
  final List<PinnedParameter> pinnedParameters;
  final TextEditingController? measurementController;
  final TextEditingController? timeController;
  final int fillCount;
  final VoidCallback onClose;
  final Function(int, int) onFillCountChanged;

  const ExpandedIndicatorCard({
    super.key,
    required this.index,
    required this.pinnedParameters,
    this.measurementController,
    this.timeController,
    required this.fillCount,
    required this.onClose,
    required this.onFillCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (index >= pinnedParameters.length) return const SizedBox.shrink();

    final param = pinnedParameters[index];
    final indicatorName = getIndicatorLabel(param.key);
    final effectiveMeasurementController =
        measurementController ?? TextEditingController();
    final effectiveTimeController = timeController ?? TextEditingController();

    final timeFormatter = MaskTextInputFormatter(
      mask: '##:##',
      filter: {'#': RegExp(r'[0-9]')},
    );

    return Container(
      key: ValueKey('expanded_indicator_$index'),
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF61B4C6), Color(0xFF317799)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left section: Title, circle, time text, save button
          Expanded(
            flex: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  indicatorName,
                  style: GoogleFonts.firaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 70,
                  height: 70,
                  child: CustomPaint(
                    size: const Size(55, 55),
                    painter: const DashedCirclePainter(),
                    child: Center(
                      child: Container(
                        width: 18,
                        height: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Выберите время',
                  style: GoogleFonts.firaSans(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      // TODO: Save data
                      onClose();
                    },
                    child: Text(
                      'Сохранить',
                      style: GoogleFonts.firaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right section: Input fields
          Expanded(
            flex: 4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMeasurementInput(effectiveMeasurementController),
                const SizedBox(height: 22),
                _buildTimeInput(
                  context,
                  effectiveTimeController,
                  timeFormatter,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementInput(TextEditingController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7DCAD6), Color(0xFF55ACBF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Заполните:',
            style: GoogleFonts.firaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: TextFormField(
              controller: controller,
              style: GoogleFonts.firaSans(
                fontSize: 12,
                color: Colors.grey.shade900,
              ),
              decoration: InputDecoration(
                hintText: 'Внесите замер',
                hintStyle: GoogleFonts.firaSans(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInput(
    BuildContext context,
    TextEditingController controller,
    MaskTextInputFormatter formatter,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7DCAD6), Color(0xFF55ACBF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Время заполнения:',
                style: GoogleFonts.firaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                '$fillCount раза в день',
                style: GoogleFonts.firaSans(fontSize: 12, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Flexible(
                child: SizedBox(
                  width: 90,
                  height: 36,
                  child: TextFormField(
                    controller: controller,
                    inputFormatters: [formatter],
                    style: GoogleFonts.firaSans(
                      fontSize: 12,
                      color: Colors.grey.shade900,
                    ),
                    decoration: InputDecoration(
                      hintText: '-:-',
                      hintStyle: GoogleFonts.firaSans(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      suffixIcon: Icon(
                        Icons.access_time,
                        color: Colors.grey.shade700,
                        size: 18,
                      ),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  if (controller.text.isNotEmpty) {
                    onFillCountChanged(index, fillCount + 1);
                    controller.clear();
                  }
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF317799),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
