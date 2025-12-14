import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_config.dart';
import '../utils/app_icons.dart';

class SelectIndicatorsPage extends StatefulWidget {
  const SelectIndicatorsPage({super.key});
  static const String routeName = '/select-indicators';

  @override
  State<SelectIndicatorsPage> createState() => _SelectIndicatorsPageState();
}

class _SelectIndicatorsPageState extends State<SelectIndicatorsPage> {
  final Set<String> _pinnedIndicators = {};
  final Set<String> _allIndicators = {};

  void _openPinnedIndicatorsDialog() {
    showDialog(
      context: context,
      builder: (context) => _IndicatorsSelectionDialog(
        title: 'Выбор показателей (закрепленных)',
        description:
            'Чтобы закрепить параметры которые важно не забывать отслеживать - нажмите на него и нажмите на кнопку выбрать, доступно не более 3 параметров',
        maxSelection: 3,
        selectedIndicators: _pinnedIndicators,
        onSelectionChanged: (selected) {
          setState(() {
            _pinnedIndicators.clear();
            _pinnedIndicators.addAll(selected);
          });
        },
      ),
    );
  }

  void _openAllIndicatorsDialog() {
    showDialog(
      context: context,
      builder: (context) => _IndicatorsSelectionDialog(
        title: 'Выбор показателей',
        description:
            'Чтобы выбрать индивидуальные параметры которые важно отслеживать - нажмите на него и после выбора всех необходимых нажмите на кнопку выбрать',
        maxSelection: null,
        selectedIndicators: _allIndicators,
        onSelectionChanged: (selected) {
          setState(() {
            _allIndicators.clear();
            _allIndicators.addAll(selected);
          });
        },
      ),
    );
  }

  void _createDiary() {
    // Navigate to health diary page
    context.pushReplacement('/health-diary');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          'Выберите показатели',
          style: GoogleFonts.firaSans(
            color: Colors.grey.shade900,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Для закрепленных показателей лучше выбирать показатели, которые нужно замерять через определенный промежуток времени: давление, пульс, температура и др.',
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pinned indicators section
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
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Закрепленные показатели',
                            style: GoogleFonts.firaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Выберите до 3-х показателей для быстрого доступа с таймером заполнения',
                            style: GoogleFonts.firaSans(
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _openPinnedIndicatorsDialog,
                            child: Text(
                              'Выбрать (${_pinnedIndicators.length}/3)',
                              style: GoogleFonts.firaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppConfig.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // All indicators section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Все показатели',
                            style: GoogleFonts.firaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey.shade900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Выберите остальные показатели для отслеживания',
                            style: GoogleFonts.firaSans(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppConfig.primaryColor),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _openAllIndicatorsDialog,
                            child: Text(
                              'Выбрать (${_allIndicators.length})',
                              style: GoogleFonts.firaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppConfig.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Create diary button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: InkWell(
                  onTap: _createDiary,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppConfig.primaryColor,
                          AppConfig.primaryColor.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Создать дневник',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.firaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IndicatorsSelectionDialog extends StatefulWidget {
  final String title;
  final String description;
  final int? maxSelection;
  final Set<String> selectedIndicators;
  final Function(Set<String>) onSelectionChanged;

  const _IndicatorsSelectionDialog({
    required this.title,
    required this.description,
    this.maxSelection,
    required this.selectedIndicators,
    required this.onSelectionChanged,
  });

  @override
  State<_IndicatorsSelectionDialog> createState() =>
      _IndicatorsSelectionDialogState();
}

class _IndicatorsSelectionDialogState
    extends State<_IndicatorsSelectionDialog> {
  late Set<String> _selectedIndicators;

  final TextEditingController _careCustomController = TextEditingController();
  final TextEditingController _physicalCustomController =
      TextEditingController();
  final TextEditingController _excretionCustomController =
      TextEditingController();
  final TextEditingController _symptomCustomController =
      TextEditingController();

  @override
  void dispose() {
    _careCustomController.dispose();
    _physicalCustomController.dispose();
    _excretionCustomController.dispose();
    _symptomCustomController.dispose();
    super.dispose();
  }

  final List<String> _careIndicators = [
    'Прогулка',
    'Когнитивные игры',
    'Смена подгузников',
    'Гигиена',
    'Увлажнение кожи',
    'Прием пищи',
    'Прием лекарств',
    'Прием витаминов',
    'Сон',
  ];

  final List<String> _physicalIndicators = [
    'Температура',
    'Артериальное давление',
    'Частота дыхания',
    'Уровень боли',
    'Сатурация',
    'Уровень сахара в крови',
  ];

  final List<String> _excretionIndicators = [
    'Выпито/выделено и цвет мочи',
    'Дефекация',
  ];

  final List<String> _symptomIndicators = [
    'Тошнота',
    'Одышка',
    'Кашель',
    'Икота',
    'Рвота',
    'Зуд',
    'Сухость во рту',
    'Нарушение вкуса',
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndicators = Set.from(widget.selectedIndicators);
  }

  void _toggleIndicator(String indicator) {
    setState(() {
      if (_selectedIndicators.contains(indicator)) {
        _selectedIndicators.remove(indicator);
      } else {
        if (widget.maxSelection != null &&
            _selectedIndicators.length >= widget.maxSelection!) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Можно выбрать не более ${widget.maxSelection} показателей',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
        _selectedIndicators.add(indicator);
      }
    });
  }

  void _confirmSelection() {
    widget.onSelectionChanged(_selectedIndicators);
    Navigator.of(context).pop();
  }

  void _addCustomIndicator(TextEditingController controller) {
    if (controller.text.trim().isNotEmpty) {
      final indicator = controller.text.trim();
      if (widget.maxSelection != null &&
          _selectedIndicators.length >= widget.maxSelection! &&
          !_selectedIndicators.contains(indicator)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Можно выбрать не более ${widget.maxSelection} показателей',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
      setState(() {
        _selectedIndicators.add(indicator);
        controller.clear();
      });
    }
  }

  Widget _buildIndicatorSection(
    String title,
    List<String> indicators,
    TextEditingController customController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: GoogleFonts.firaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: indicators.map((indicator) {
            final isSelected = _selectedIndicators.contains(indicator);
            return InkWell(
              onTap: () => _toggleIndicator(indicator),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppConfig.primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppConfig.primaryColor
                        : AppConfig.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  indicator,
                  style: GoogleFonts.firaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey.shade800,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: customController,
                decoration: InputDecoration(
                  hintText: 'Добавить показатель не из списка',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppConfig.primaryColor.withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppConfig.primaryColor.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _addCustomIndicator(customController),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppConfig.primaryColor,
                      AppConfig.primaryColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          minWidth: MediaQuery.of(context).size.width * 0.92,
        ),
        width: MediaQuery.of(context).size.width * 0.92,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.firaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppConfig.primaryColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.description,
                      style: GoogleFonts.firaSans(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildIndicatorSection(
                      'Показатели ухода',
                      _careIndicators,
                      _careCustomController,
                    ),
                    _buildIndicatorSection(
                      'Физические показатели',
                      _physicalIndicators,
                      _physicalCustomController,
                    ),
                    _buildIndicatorSection(
                      'Выделение мочи и кала',
                      _excretionIndicators,
                      _excretionCustomController,
                    ),
                    _buildIndicatorSection(
                      'Тягостные симптомы',
                      _symptomIndicators,
                      _symptomCustomController,
                    ),
                  ],
                ),
              ),
            ),
            // Footer button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _confirmSelection,
                  child: Text(
                    'Выбрать',
                    style: GoogleFonts.firaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
