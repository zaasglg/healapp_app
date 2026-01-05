import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/app_config.dart';
import '../../../repositories/diary_repository.dart';
import '../../../utils/app_icons.dart';
import '../utils/indicator_utils.dart';
import '../widgets/pinned_indicators_section.dart';
import '../widgets/expandable_section.dart';

/// Таб "Дневник" для страницы дневника здоровья
class DiaryTab extends StatefulWidget {
  final Diary? diary;
  final AnimationController animationController;
  final Animation<double> expandAnimation;
  final int? selectedIndicatorIndex;
  final int? animatingFromIndex;
  final Function(int) onIndicatorSelected;
  final VoidCallback onIndicatorClosed;
  final Function(BuildContext, String, String) onShowIndicatorModal;

  const DiaryTab({
    super.key,
    required this.diary,
    required this.animationController,
    required this.expandAnimation,
    required this.selectedIndicatorIndex,
    required this.animatingFromIndex,
    required this.onIndicatorSelected,
    required this.onIndicatorClosed,
    required this.onShowIndicatorModal,
  });

  @override
  State<DiaryTab> createState() => _DiaryTabState();
}

class _DiaryTabState extends State<DiaryTab> {
  bool _isPhysicalExpanded = false;
  bool _isExcretionExpanded = false;
  bool _isAccessManagementExpanded = false;

  final Map<int, TextEditingController> _measurementControllers = {};
  final Map<int, TextEditingController> _timeControllers = {};
  final Map<int, int> _fillCounts = {};

  @override
  void dispose() {
    for (final controller in _measurementControllers.values) {
      controller.dispose();
    }
    for (final controller in _timeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pinnedParameters = widget.diary?.pinnedParameters ?? [];

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPinnedIndicatorsSection(pinnedParameters),
                  const SizedBox(height: 32),
                  _buildAllIndicatorsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedIndicatorsSection(List<PinnedParameter> pinnedParameters) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Закрепленные показатели',
          style: GoogleFonts.firaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 12),
        PinnedIndicatorsSection(
          pinnedParameters: pinnedParameters,
          animationController: widget.animationController,
          expandAnimation: widget.expandAnimation,
          selectedIndicatorIndex: widget.selectedIndicatorIndex,
          animatingFromIndex: widget.animatingFromIndex,
          onIndicatorSelected: widget.onIndicatorSelected,
          onIndicatorClosed: widget.onIndicatorClosed,
          measurementControllers: _measurementControllers,
          timeControllers: _timeControllers,
          fillCounts: _fillCounts,
          onFillCountChanged: (index, count) {
            setState(() {
              _fillCounts[index] = count;
            });
          },
        ),
      ],
    );
  }

  Widget _buildAllIndicatorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Все показатели',
          style: GoogleFonts.firaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 12),
        _buildDiagnosesCard(),
        _buildIndicatorsCard(),
        _buildChangeIndicatorsButton(),
        const SizedBox(height: 12),
        _buildAccessManagementCard(),
      ],
    );
  }

  Widget _buildDiagnosesCard() {
    final diagnoses = widget.diary?.patient?.diagnoses ?? [];

    return ExpandableSection(
      title: 'Диагнозы пациента',
      subtitle: diagnoses.isNotEmpty
          ? diagnoses.take(3).join(', ') +
                (diagnoses.length > 3 ? ' и т.д.' : '')
          : 'Диагнозы не указаны',
      isExpanded: _isPhysicalExpanded,
      onToggle: () {
        setState(() {
          _isPhysicalExpanded = !_isPhysicalExpanded;
        });
      },
      expandedContent: diagnoses.isNotEmpty
          ? GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.5,
              ),
              itemCount: diagnoses.length,
              itemBuilder: (context, index) {
                return Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppConfig.primaryColor.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    diagnoses[index],
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            )
          : Text(
              'У пациента не указаны диагнозы',
              style: GoogleFonts.firaSans(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
    );
  }

  Widget _buildIndicatorsCard() {
    final settings = widget.diary?.settings;
    final allIndicators = settings?['all_indicators'] as List<dynamic>? ?? [];

    return ExpandableSection(
      title: 'Показатели ухода',
      subtitle: allIndicators.isNotEmpty
          ? allIndicators
                    .take(3)
                    .map((e) => getIndicatorLabel(e.toString()))
                    .join(', ') +
                (allIndicators.length > 3 ? ' и т.д.' : '')
          : 'Показатели не заданы',
      isExpanded: _isExcretionExpanded,
      onToggle: () {
        setState(() {
          _isExcretionExpanded = !_isExcretionExpanded;
        });
      },
      expandedContent: allIndicators.isNotEmpty
          ? GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.5,
              ),
              itemCount: allIndicators.length,
              itemBuilder: (context, index) {
                final key = allIndicators[index].toString();
                final label = getIndicatorLabel(key);
                return GestureDetector(
                  onTap: () => widget.onShowIndicatorModal(context, key, label),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppConfig.primaryColor.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.firaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            )
          : Text(
              'Показатели ухода не заданы',
              style: GoogleFonts.firaSans(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
    );
  }

  Widget _buildChangeIndicatorsButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        onPressed: () {
          // TODO: Open change indicators dialog
        },
        child: Text(
          'Изменить показатели',
          style: GoogleFonts.firaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppConfig.primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildAccessManagementCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isAccessManagementExpanded = !_isAccessManagementExpanded;
              });
            },
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: Radius.circular(_isAccessManagementExpanded ? 0 : 12),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  Text(
                    'Управление доступом',
                    style: GoogleFonts.firaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 3),
                  Center(
                    child: Transform.rotate(
                      angle: _isAccessManagementExpanded ? 4.71239 : 1.5708,
                      child: Image.asset(
                        AppIcons.chevron_right,
                        width: 20,
                        height: 20,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isAccessManagementExpanded) _buildAccessManagementContent(),
        ],
      ),
    );
  }

  Widget _buildAccessManagementContent() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Текущий доступ',
            style: GoogleFonts.firaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Организация (этот аккаунт)',
            style: GoogleFonts.firaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ID: e252b78d-5b09-4417-a9e1-2e9264d501d3',
            style: GoogleFonts.firaSans(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade300, height: 1),
          const SizedBox(height: 12),
          Text(
            'Все сотрудники пансионата имеют доступ к дневнику автоматически.',
            style: GoogleFonts.firaSans(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Организация',
                      style: GoogleFonts.firaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Организация',
                      style: GoogleFonts.firaSans(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
                onPressed: () {
                  // TODO: Handle delete organization
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
