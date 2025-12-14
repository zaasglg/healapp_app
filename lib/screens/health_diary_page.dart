import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../config/app_config.dart';
import '../utils/app_icons.dart';
import '../bloc/route_sheet/route_sheet_cubit.dart';
import '../bloc/route_sheet/route_sheet_state.dart';

class HealthDiaryPage extends StatefulWidget {
  const HealthDiaryPage({super.key});
  static const String routeName = '/health-diary';

  @override
  State<HealthDiaryPage> createState() => _HealthDiaryPageState();
}

class _HealthDiaryPageState extends State<HealthDiaryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _selectedDate;

  // Diary tab state
  final List<String> _pinnedIndicators = [
    'Давление',
    'Смена подгузников',
    'Прогулка',
  ];
  bool _isPhysicalExpanded = false;
  bool _isExcretionExpanded = false;
  bool _isAccessManagementExpanded = false;
  bool _isHistoryDatePickerExpanded = false;
  bool _isRouteSheetDatePickerExpanded = false;
  int? _selectedIndicatorIndex;
  final Set<String> _selectedPhysicalIndicators = {};
  final Set<String> _selectedExcretionIndicators = {};

  final List<String> _physicalIndicators = [
    'Частота дыхания',
    'Температура',
    'Давление',
    'Пульс',
    'Сатурация',
  ];

  final List<String> _excretionIndicators = [
    'Выпито жидкости',
    'Выделено мочи',
    'Цвет мочи',
    'Дефекация',
  ];
  final Map<int, TextEditingController> _measurementControllers = {};
  final Map<int, TextEditingController> _timeControllers = {};
  final Map<int, int> _fillCounts = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _selectedDate = DateTime.now();
    // Initialize Russian locale
    initializeDateFormatting('ru', null);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RouteSheetCubit()..setSelectedDate(_selectedDate),
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
            'Дневник здоровья',
            style: GoogleFonts.firaSans(
              color: Colors.grey.shade900,
              fontWeight: FontWeight.w700,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppConfig.primaryColor,
                indicatorWeight: 2,
                labelColor: Colors.grey.shade900,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: GoogleFonts.firaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: GoogleFonts.firaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                tabs: const [
                  Tab(text: 'Дневник'),
                  Tab(text: 'История'),
                  Tab(text: 'Маршрутный лист'),
                  Tab(text: 'Клиент'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildDiaryTab(),
            _buildHistoryTab(),
            _buildRouteSheetTab(),
            _buildClientTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildDiaryTab() {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pinned indicators section
                  Text(
                    'Закрепленные показатели',
                    style: GoogleFonts.firaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Show expanded card or horizontal list
                  if (_selectedIndicatorIndex != null)
                    _buildExpandedIndicatorCard(_selectedIndicatorIndex!)
                  else if (_pinnedIndicators.isNotEmpty)
                    Row(
                      children: List.generate(_pinnedIndicators.length, (
                        index,
                      ) {
                        final indicator = _pinnedIndicators[index];
                        return Expanded(
                          child: Container(
                            height: 240,
                            margin: EdgeInsets.only(
                              right: index < _pinnedIndicators.length - 1
                                  ? 8
                                  : 0,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF61B4C6),
                                  const Color(0xFF317799),
                                ],
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
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  indicator,
                                  style: GoogleFonts.firaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: 70,
                                  height: 70,
                                  child: CustomPaint(
                                    size: const Size(50, 50),
                                    painter: _DashedCirclePainter(),
                                    child: Center(
                                      child: Container(
                                        width: 24,
                                        height: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: Text(
                                    'Выберите время',
                                    style: GoogleFonts.firaSans(
                                      fontSize: 10,
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w800,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade800,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _selectedIndicatorIndex = index;
                                        if (!_measurementControllers
                                            .containsKey(index)) {
                                          _measurementControllers[index] =
                                              TextEditingController();
                                          _timeControllers[index] =
                                              TextEditingController();
                                          _fillCounts[index] = 0;
                                        }
                                      });
                                    },
                                    child: Text(
                                      'Заполнить',
                                      style: GoogleFonts.firaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  const SizedBox(height: 32),
                  // All indicators section
                  Text(
                    'Все показатели',
                    style: GoogleFonts.firaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Physical indicators card
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isPhysicalExpanded = !_isPhysicalExpanded;
                            });
                          },
                          borderRadius: BorderRadius.vertical(
                            top: const Radius.circular(16),
                            bottom: Radius.circular(
                              _isPhysicalExpanded ? 0 : 16,
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Физические показатели',
                                      style: GoogleFonts.firaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey.shade900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Температура, давление, сатурация и т.д.',
                                      style: GoogleFonts.firaSans(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: Transform.rotate(
                                    angle: _isPhysicalExpanded
                                        ? 4.71239
                                        : 1.5708,
                                    child: Image.asset(
                                      AppIcons.chevron_right,
                                      width: 24,
                                      height: 24,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isPhysicalExpanded)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(16),
                              ),
                            ),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: _physicalIndicators.map((indicator) {
                                final isSelected = _selectedPhysicalIndicators
                                    .contains(indicator);
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedPhysicalIndicators.remove(
                                          indicator,
                                        );
                                      } else {
                                        _selectedPhysicalIndicators.add(
                                          indicator,
                                        );
                                        // Show modal for input
                                        _showIndicatorInputDialog(
                                          context,
                                          indicator,
                                          'physical',
                                        );
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppConfig.primaryColor.withOpacity(
                                              0.1,
                                            )
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppConfig.primaryColor
                                            .withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      indicator,
                                      style: GoogleFonts.firaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? AppConfig.primaryColor
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Excretion indicators card
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isExcretionExpanded = !_isExcretionExpanded;
                            });
                          },
                          borderRadius: BorderRadius.vertical(
                            top: const Radius.circular(16),
                            bottom: Radius.circular(
                              _isExcretionExpanded ? 0 : 16,
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Выделение мочи и кала',
                                      style: GoogleFonts.firaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey.shade900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Выпито/выделено, цвет мочи и дефекация',
                                      style: GoogleFonts.firaSans(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: Transform.rotate(
                                    angle: _isExcretionExpanded
                                        ? 4.71239
                                        : 1.5708,
                                    child: Image.asset(
                                      AppIcons.chevron_right,
                                      width: 24,
                                      height: 24,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isExcretionExpanded)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(16),
                              ),
                            ),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: _excretionIndicators.map((indicator) {
                                final isSelected = _selectedExcretionIndicators
                                    .contains(indicator);
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedExcretionIndicators.remove(
                                          indicator,
                                        );
                                      } else {
                                        _selectedExcretionIndicators.add(
                                          indicator,
                                        );
                                        // Show modal for input
                                        _showIndicatorInputDialog(
                                          context,
                                          indicator,
                                          'excretion',
                                        );
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppConfig.primaryColor.withOpacity(
                                              0.1,
                                            )
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppConfig.primaryColor
                                            .withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      indicator,
                                      style: GoogleFonts.firaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? AppConfig.primaryColor
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),

                  Container(
                    child: Column(
                      children: [
                        Container(
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
                        ),
                        const SizedBox(height: 12),
                        // Access management section
                        Container(
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
                                    _isAccessManagementExpanded =
                                        !_isAccessManagementExpanded;
                                  });
                                },
                                borderRadius: BorderRadius.vertical(
                                  top: const Radius.circular(12),
                                  bottom: Radius.circular(
                                    _isAccessManagementExpanded ? 0 : 12,
                                  ),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
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
                                          angle: _isAccessManagementExpanded
                                              ? 4.71239
                                              : 1.5708,
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
                              if (_isAccessManagementExpanded)
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(12),
                                    ),
                                    border: Border(
                                      top: BorderSide(
                                        color: Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
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
                                      // First section: Organization (this account)
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
                                      Divider(
                                        color: Colors.grey.shade300,
                                        height: 1,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Все сотрудники пансионата имеют доступ к дневнику автоматически.',
                                        style: GoogleFonts.firaSans(
                                          fontSize: 13,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      // Second section: Organization
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
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
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedIndicatorCard(int index) {
    final indicatorName = _pinnedIndicators[index];
    final measurementController =
        _measurementControllers[index] ?? TextEditingController();
    final timeController = _timeControllers[index] ?? TextEditingController();

    if (!_measurementControllers.containsKey(index)) {
      _measurementControllers[index] = measurementController;
      _timeControllers[index] = timeController;
      _fillCounts[index] = 0;
    }

    final timeFormatter = MaskTextInputFormatter(
      mask: '##:##',
      filter: {'#': RegExp(r'[0-9]')},
    );

    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF61B4C6), const Color(0xFF317799)],
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
                    painter: _DashedCirclePainter(),
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
                SizedBox(height: 10),
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
                      setState(() {
                        _selectedIndicatorIndex = null;
                      });
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF7DCAD6),
                        const Color(0xFF55ACBF),
                      ],
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
                          controller: measurementController,
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
                ),
                SizedBox(height: 22),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF7DCAD6),
                        const Color(0xFF55ACBF),
                      ],
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
                            '${_fillCounts[index] ?? 0} раза в день',
                            style: GoogleFonts.firaSans(
                              fontSize: 12,
                              color: Colors.white,
                            ),
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
                                controller: timeController,
                                inputFormatters: [timeFormatter],
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
                              if (timeController.text.isNotEmpty) {
                                setState(() {
                                  _fillCounts[index] =
                                      (_fillCounts[index] ?? 0) + 1;
                                });
                                timeController.clear();
                              }
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF317799),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineCalendar(
    DateTime initialDate,
    Function(DateTime) onDateSelected,
  ) {
    return StatefulBuilder(
      builder: (context, setState) {
        DateTime selectedDate = initialDate;
        DateTime currentMonth = DateTime(initialDate.year, initialDate.month);

        return Container(
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
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with month navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        currentMonth = DateTime(
                          currentMonth.year,
                          currentMonth.month - 1,
                        );
                      });
                    },
                  ),
                  Text(
                    DateFormat('MMMM y', 'ru').format(currentMonth),
                    style: GoogleFonts.firaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() {
                        currentMonth = DateTime(
                          currentMonth.year,
                          currentMonth.month + 1,
                        );
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Calendar
              _buildCalendarGrid(currentMonth, selectedDate, (date) {
                setState(() {
                  selectedDate = date;
                });
                onDateSelected(date);
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalendarGrid(
    DateTime month,
    DateTime selectedDate,
    Function(DateTime) onDateTap,
  ) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final firstDayWeekday = firstDay.weekday == 7 ? 0 : firstDay.weekday;
    final daysInMonth = lastDay.day;
    final daysInPrevMonth = DateTime(month.year, month.month, 0).day;

    final List<Widget> dayWidgets = [];
    final weekDays = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

    // Week day headers
    for (var day in weekDays) {
      dayWidgets.add(
        Container(
          height: 40,
          alignment: Alignment.center,
          child: Text(
            day,
            style: GoogleFonts.firaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    // Previous month days
    for (int i = firstDayWeekday - 1; i >= 0; i--) {
      final day = daysInPrevMonth - i;
      dayWidgets.add(
        Container(
          height: 40,
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: GoogleFonts.firaSans(
              fontSize: 14,
              color: Colors.grey.shade300,
            ),
          ),
        ),
      );
    }

    // Current month days
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final isSelected =
          date.year == selectedDate.year &&
          date.month == selectedDate.month &&
          date.day == selectedDate.day;
      final isToday =
          date.year == DateTime.now().year &&
          date.month == DateTime.now().month &&
          date.day == DateTime.now().day;

      dayWidgets.add(
        GestureDetector(
          onTap: () => onDateTap(date),
          child: Container(
            height: 40,
            width: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppConfig.primaryColor.withOpacity(0.2)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppConfig.primaryColor : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$day',
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: isSelected
                      ? Colors.white
                      : isToday
                      ? AppConfig.primaryColor
                      : Colors.grey.shade900,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Next month days
    final remainingDays = 42 - dayWidgets.length;
    for (int day = 1; day <= remainingDays; day++) {
      dayWidgets.add(
        Container(
          height: 40,
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: GoogleFonts.firaSans(
              fontSize: 14,
              color: Colors.grey.shade300,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: dayWidgets.length,
      itemBuilder: (context, index) => dayWidgets[index],
    );
  }

  void _showIndicatorInputDialog(
    BuildContext context,
    String indicatorName,
    String category,
  ) {
    final TextEditingController valueController = TextEditingController();

    // Descriptions for different indicators
    final Map<String, String> descriptions = {
      'Частота дыхания': 'Количество вдохов в минуту.',
      'Температура': 'Температура тела в градусах Цельсия.',
      'Давление': 'Артериальное давление (систолическое/диастолическое).',
      'Пульс': 'Количество ударов сердца в минуту.',
      'Сатурация': 'Насыщение крови кислородом в процентах.',
      'Выпито жидкости': 'Количество выпитой жидкости в миллилитрах.',
      'Выделено мочи': 'Количество выделенной мочи в миллилитрах.',
      'Цвет мочи': 'Описание цвета мочи.',
      'Дефекация': 'Описание дефекации.',
    };

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Text(
                indicatorName,
                textAlign: TextAlign.center,
                style: GoogleFonts.firaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 16),
              // Description 1
              Text(
                descriptions[indicatorName] ?? 'Введите значение показателя.',
                textAlign: TextAlign.center,
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              // Description 2
              Text(
                'Время заполнения фиксируется автоматически',
                textAlign: TextAlign.center,
                style: GoogleFonts.firaSans(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 24),
              // Value label
              Text(
                'Значение',
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 8),
              // Input field
              TextFormField(
                controller: valueController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  color: Colors.grey.shade900,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppConfig.primaryColor,
                      width: 1,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Remove indicator from selection if cancelled
                        setState(() {
                          if (category == 'physical') {
                            _selectedPhysicalIndicators.remove(indicatorName);
                          } else {
                            _selectedExcretionIndicators.remove(indicatorName);
                          }
                        });
                      },
                      child: Text(
                        'Отмена',
                        style: GoogleFonts.firaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        // TODO: Save value
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                        child: Text(
                          'Сохранить',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.firaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
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
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isHistoryDatePickerExpanded =
                            !_isHistoryDatePickerExpanded;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppConfig.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat(
                              'EEEE, d MMMM yг',
                              'ru',
                            ).format(_selectedDate),
                            style: GoogleFonts.firaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppConfig.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Отчёт будет построен за этот день',
                    style: GoogleFonts.firaSans(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (_isHistoryDatePickerExpanded) ...[
                    const SizedBox(height: 16),
                    _buildInlineCalendar(_selectedDate, (date) {
                      setState(() {
                        _selectedDate = date;
                        _isHistoryDatePickerExpanded = false;
                      });
                    }),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 24),
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
                  // Смена подгузников
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'СМЕНА ПОДГУЗНИКОВ',
                        style: GoogleFonts.firaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '122',
                              style: GoogleFonts.firaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade900,
                              ),
                            ),
                            Text(
                              '04:07',
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
                  ),
                  const SizedBox(height: 16),
                  // Температура
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ТЕМПЕРАТУРА',
                        style: GoogleFonts.firaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '2°C',
                              style: GoogleFonts.firaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade900,
                              ),
                            ),
                            Text(
                              '10:25',
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteSheetTab() {
    return BlocBuilder<RouteSheetCubit, RouteSheetState>(
      builder: (context, state) {
        final tasksForDate = state.getTasksForDate(state.selectedDate);
        final hasTasks = state.tasks.isNotEmpty;

        if (!hasTasks) {
          // Показываем стандартный UI, если нет задач
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
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
                    child: Text(
                      'Маршрутный лист показывает, какие манипуляции нужно выполнять с подопечным, когда и с какой периодичностью (ежедневно, раз в неделю). Можно составить вручную или воспользоваться ИИ, который предложит готовый вариант на основе дневника динамики ухода. С маршрутным листом легко согласовать, изменить и отслеживать выполнение всех процедур.',
                      style: GoogleFonts.firaSans(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Настроить маршрутный лист',
                    style: GoogleFonts.firaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                          'Добавьте манипуляции вручную или с помощью ИИ',
                          style: GoogleFonts.firaSans(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade800,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            _showManipulationsBottomSheet(context);
                          },
                          child: Text(
                            'Добавить',
                            style: GoogleFonts.firaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConfig.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            // TODO: Implement AI add
                          },
                          child: Text(
                            'Добавить с ИИ',
                            style: GoogleFonts.firaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Показываем данные в виде временных слотов
        return SafeArea(
          child: Column(
            children: [
              // Дата выбора
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isRouteSheetDatePickerExpanded =
                              !_isRouteSheetDatePickerExpanded;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppConfig.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat(
                                'EEEE, d MMMM yг',
                                'ru',
                              ).format(state.selectedDate),
                              style: GoogleFonts.firaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppConfig.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              color: AppConfig.primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isRouteSheetDatePickerExpanded) ...[
                      const SizedBox(height: 16),
                      _buildInlineCalendar(state.selectedDate, (date) {
                        context.read<RouteSheetCubit>().setSelectedDate(date);
                        setState(() {
                          _isRouteSheetDatePickerExpanded = false;
                        });
                      }),
                    ],
                  ],
                ),
              ),
              // Манипуляции на сегодня
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Манипуляции на сегодня',
                        style: GoogleFonts.firaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(child: _buildTimeSlots(tasksForDate)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade800,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            // TODO: Implement edit
                          },
                          child: Text(
                            'Изменить',
                            style: GoogleFonts.firaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeSlots(List<RouteSheetTask> tasks) {
    // Группируем задачи по времени
    final Map<String, List<RouteSheetTask>> tasksByTime = {};
    for (var task in tasks) {
      final time = task.time.split(' - ')[0]; // Берем время начала
      if (!tasksByTime.containsKey(time)) {
        tasksByTime[time] = [];
      }
      tasksByTime[time]!.add(task);
    }

    // Создаем список всех временных слотов (07:00 - 23:00)
    final List<String> timeSlots = [];
    for (int hour = 7; hour < 24; hour++) {
      timeSlots.add('${hour.toString().padLeft(2, '0')}:00');
    }

    return ListView.builder(
      itemCount: timeSlots.length,
      itemBuilder: (context, index) {
        final timeSlot = timeSlots[index];
        final slotTasks = tasksByTime[timeSlot] ?? [];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Время
              SizedBox(
                width: 60,
                child: Text(
                  timeSlot,
                  style: GoogleFonts.firaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Задачи
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: slotTasks.isEmpty
                      ? [
                          // Пустой слот
                          Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ]
                      : slotTasks.map((task) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildTaskCard(task),
                          );
                        }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskCard(RouteSheetTask task) {
    Color backgroundColor;
    Color buttonColor;
    String statusText;

    switch (task.status) {
      case TaskStatus.completed:
        backgroundColor = AppConfig.primaryColor.withOpacity(0.1);
        buttonColor = AppConfig.primaryColor;
        statusText = 'Выполненная задача';
        break;
      case TaskStatus.planned:
        backgroundColor = const Color(0xFF00BCD4).withOpacity(0.1);
        buttonColor = const Color(0xFF00BCD4);
        statusText = 'Поставленная задача';
        break;
      case TaskStatus.postponed:
        backgroundColor = Colors.orange.withOpacity(0.1);
        buttonColor = Colors.orange;
        statusText = 'Перенесенная задача';
        break;
      case TaskStatus.uncompleted:
        backgroundColor = Colors.red.withOpacity(0.1);
        buttonColor = Colors.red;
        statusText = 'Не выполненная задача';
        break;
    }

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusText,
              style: GoogleFonts.firaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            // TODO: Open fill dialog
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
            minimumSize: const Size(80, 40),
          ),
          child: Text(
            'Заполнить',
            style: GoogleFonts.firaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClientTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Share diary card
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Поделитесь дневником с клиентом',
                    style: GoogleFonts.firaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Отправьте ссылку клиенту, чтобы он получил доступ к карточке подопечного и дневнику. Ссылка сохранится в его личном кабинете.',
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Create link card
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
                    'Пока ссылка не создана. Нажмите кнопку ниже, чтобы сформировать персональную ссылку для клиента.',
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: InkWell(
                      onTap: () {
                        // TODO: Implement create link functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ссылка создана'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
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
                          'Создать ссылку',
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManipulationsBottomSheet(BuildContext context) {
    final Set<String> selectedManipulations = {};
    final TextEditingController careIndicatorController =
        TextEditingController();
    final TextEditingController physicalIndicatorController =
        TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Выбор манипуляций',
                      style: GoogleFonts.firaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppConfig.primaryColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
              ),
              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Чтобы выбрать манипуляции, которые необходимо выполнять специалисту, выберите их, укажите дни, по которым нужно проводить а также порядок выполнения',
                  style: GoogleFonts.firaSans(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Манипуляции ухода
                      Text(
                        'Манипуляции ухода',
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
                        children:
                            [
                              'Прогулка',
                              'Когнитивные игры',
                              'Смена подгузников',
                              'Гигиена',
                              'Увлажнение кожи',
                              'Прием пищи',
                              'Прием лекарств',
                              'Прием витаминов',
                            ].map((item) {
                              final isSelected = selectedManipulations.contains(
                                item,
                              );
                              return GestureDetector(
                                onTap: () {
                                  _showManipulationSettingsModal(
                                    context,
                                    item,
                                    (shouldAdd) {
                                      setModalState(() {
                                        if (shouldAdd) {
                                          selectedManipulations.add(item);
                                        } else {
                                          selectedManipulations.remove(item);
                                        }
                                      });
                                    },
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppConfig.primaryColor.withOpacity(
                                            0.1,
                                          )
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppConfig.primaryColor
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    item,
                                    style: GoogleFonts.firaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? AppConfig.primaryColor
                                          : Colors.grey.shade900,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 16),
                      // Добавить показатель для ухода
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: careIndicatorController,
                              decoration: InputDecoration(
                                hintText: 'Введите название показателя',
                                hintStyle: GoogleFonts.firaSans(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              style: GoogleFonts.firaSans(
                                fontSize: 14,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              if (careIndicatorController.text.isNotEmpty) {
                                // TODO: Add custom indicator
                                careIndicatorController.clear();
                              }
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppConfig.primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Физические манипуляции
                      Text(
                        'Физические манипуляции',
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
                        children:
                            [
                              'Температура',
                              'Артериальное давление',
                              'Частота дыхания',
                              'Уровень боли',
                              'Сатурация',
                              'Уровень сахара в крови',
                              'Выпито/выделено и цвет мочи',
                              'Дефекация',
                              'Пульс',
                            ].map((item) {
                              final isSelected = selectedManipulations.contains(
                                item,
                              );
                              return GestureDetector(
                                onTap: () {
                                  _showManipulationSettingsModal(
                                    context,
                                    item,
                                    (shouldAdd) {
                                      setModalState(() {
                                        if (shouldAdd) {
                                          selectedManipulations.add(item);
                                        } else {
                                          selectedManipulations.remove(item);
                                        }
                                      });
                                    },
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppConfig.primaryColor.withOpacity(
                                            0.1,
                                          )
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppConfig.primaryColor
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    item,
                                    style: GoogleFonts.firaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? AppConfig.primaryColor
                                          : Colors.grey.shade900,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 16),
                      // Добавить показатель для физических
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: physicalIndicatorController,
                              decoration: InputDecoration(
                                hintText: 'Введите название показателя',
                                hintStyle: GoogleFonts.firaSans(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              style: GoogleFonts.firaSans(
                                fontSize: 14,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              if (physicalIndicatorController.text.isNotEmpty) {
                                // TODO: Add custom indicator
                                physicalIndicatorController.clear();
                              }
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppConfig.primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              // Bottom button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Handle selected manipulations
                      context.pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
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
      ),
    ).then((_) {
      careIndicatorController.dispose();
      physicalIndicatorController.dispose();
    });
  }

  void _showManipulationSettingsModal(
    BuildContext context,
    String manipulationName,
    Function(bool shouldAdd) onSave,
  ) {
    final TextEditingController timeFromController = TextEditingController();
    final TextEditingController timeToController = TextEditingController();
    final timeMaskFormatter = MaskTextInputFormatter(
      mask: '##:##',
      filter: {"#": RegExp(r'[0-9]')},
    );

    // Сохраняем контекст с доступом к BLoC
    final parentContext = context;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => _ManipulationSettingsModalContent(
        manipulationName: manipulationName,
        onSave: onSave,
        timeFromController: timeFromController,
        timeToController: timeToController,
        timeMaskFormatter: timeMaskFormatter,
        parentContext: parentContext,
      ),
    ).then((_) {
      // Dispose контроллеров только после полного закрытия модалки
      // Задержка нужна, чтобы модалка успела полностью закрыться
      Future.delayed(const Duration(milliseconds: 500), () {
        try {
          timeFromController.dispose();
        } catch (e) {
          // Already disposed or still in use
        }
        try {
          timeToController.dispose();
        } catch (e) {
          // Already disposed or still in use
        }
      });
    });
  }
}

class _ManipulationSettingsModalContent extends StatefulWidget {
  final String manipulationName;
  final Function(bool shouldAdd) onSave;
  final TextEditingController timeFromController;
  final TextEditingController timeToController;
  final MaskTextInputFormatter timeMaskFormatter;
  final BuildContext parentContext;

  const _ManipulationSettingsModalContent({
    required this.manipulationName,
    required this.onSave,
    required this.timeFromController,
    required this.timeToController,
    required this.timeMaskFormatter,
    required this.parentContext,
  });

  @override
  State<_ManipulationSettingsModalContent> createState() =>
      _ManipulationSettingsModalContentState();
}

class _ManipulationSettingsModalContentState
    extends State<_ManipulationSettingsModalContent> {
  final Set<int> selectedDays = {};
  final List<String> selectedTimes = [];

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setModalState) {
        final screenHeight = MediaQuery.of(context).size.height;
        final maxHeight = screenHeight * 0.9;

        return Container(
          height: maxHeight,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Настройка манипуляции',
                      style: GoogleFonts.firaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppConfig.primaryColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Выберите дни недели, в которые необходимо выполнять манипуляцию',
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Days of week
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            [
                              {'label': 'Пн', 'value': 1},
                              {'label': 'Вт', 'value': 2},
                              {'label': 'Ср', 'value': 3},
                              {'label': 'Чт', 'value': 4},
                              {'label': 'Пт', 'value': 5},
                              {'label': 'Сб', 'value': 6},
                              {'label': 'Вс', 'value': 7},
                            ].map((day) {
                              final dayValue = day['value'] as int;
                              final dayLabel = day['label'] as String;
                              final isSelected = selectedDays.contains(
                                dayValue,
                              );
                              return GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    if (isSelected) {
                                      selectedDays.remove(dayValue);
                                    } else {
                                      selectedDays.add(dayValue);
                                    }
                                  });
                                },
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppConfig.primaryColor
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppConfig.primaryColor
                                          : Colors.grey.shade300,
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      dayLabel,
                                      style: GoogleFonts.firaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey.shade900,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 24),
                      // Выбор времени
                      Text(
                        'Выберите время',
                        style: GoogleFonts.firaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Selected time chips
                      if (selectedTimes.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: selectedTimes.map((time) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppConfig.primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    time,
                                    style: GoogleFonts.firaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        selectedTimes.remove(time);
                                      });
                                    },
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      if (selectedTimes.isNotEmpty) const SizedBox(height: 12),
                      // Time inputs
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: widget.timeFromController,
                              inputFormatters: [widget.timeMaskFormatter],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Время с',
                                labelStyle: GoogleFonts.firaSans(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                                hintText: '00:00',
                                hintStyle: GoogleFonts.firaSans(
                                  fontSize: 14,
                                  color: Colors.grey.shade400,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              style: GoogleFonts.firaSans(
                                fontSize: 14,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: widget.timeToController,
                              inputFormatters: [widget.timeMaskFormatter],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Время до',
                                labelStyle: GoogleFonts.firaSans(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                                hintText: '00:00',
                                hintStyle: GoogleFonts.firaSans(
                                  fontSize: 14,
                                  color: Colors.grey.shade400,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              style: GoogleFonts.firaSans(
                                fontSize: 14,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              try {
                                if (widget.timeFromController.text.isNotEmpty &&
                                    widget.timeToController.text.isNotEmpty) {
                                  setModalState(() {
                                    selectedTimes.add(
                                      '${widget.timeFromController.text} - ${widget.timeToController.text}',
                                    );
                                    widget.timeFromController.clear();
                                    widget.timeToController.clear();
                                  });
                                }
                              } catch (e) {
                                // Controllers already disposed
                              }
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppConfig.primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              // Bottom buttons
              Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (context.mounted) {
                            context.pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Отмена',
                          style: GoogleFonts.firaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Валидация
                          if (selectedDays.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Выберите хотя бы один день недели',
                                  style: GoogleFonts.firaSans(),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (selectedTimes.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Добавьте хотя бы одно время',
                                  style: GoogleFonts.firaSans(),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          // Сохраняем задачу в BLoC
                          // Используем родительский контекст для доступа к BLoC
                          final routeSheetCubit = widget.parentContext
                              .read<RouteSheetCubit>();
                          for (var timeRange in selectedTimes) {
                            final task = RouteSheetTask(
                              id:
                                  DateTime.now().millisecondsSinceEpoch
                                      .toString() +
                                  timeRange +
                                  widget.manipulationName,
                              name: widget.manipulationName,
                              time: timeRange,
                              status: TaskStatus.planned,
                              daysOfWeek: selectedDays.toList(),
                              order: selectedDays.length > 0
                                  ? selectedDays.first
                                  : null,
                            );
                            routeSheetCubit.addTask(task);
                          }
                          widget.onSave(true);
                          if (context.mounted) {
                            context.pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Сохранить',
                          style: GoogleFonts.firaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Custom painter for dashed circle
class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    // Draw circle with radial gradient
    final gradient = RadialGradient(
      colors: [
        const Color(0xFFA0E7E5).withOpacity(0.3),
        const Color(0xFF61B4C6).withOpacity(0.2),
      ],
    );
    final circlePaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, circlePaint);

    // Draw dashed outline with rectangular dashes
    final dashPaint = Paint()
      ..color = const Color(0xFFA0E7E5).withOpacity(0.6)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const dashCount = 20;
    const dashAngle = (2 * 3.14159) / dashCount;
    const dashLength =
        dashAngle * 0.4; // 40% of dash angle for dash, 60% for space

    for (int i = 0; i < dashCount; i++) {
      final angle = i * dashAngle;
      final startAngle = angle;
      final endAngle = angle + dashLength;

      final path = Path();
      path.addArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        endAngle - startAngle,
      );
      canvas.drawPath(path, dashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
