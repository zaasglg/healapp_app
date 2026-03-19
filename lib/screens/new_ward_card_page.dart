import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:toastification/toastification.dart';
import '../config/app_config.dart';
import '../utils/app_icons.dart';
import '../bloc/patient/patient_bloc.dart';
import '../bloc/patient/patient_event.dart';
import '../bloc/patient/patient_state.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';
import '../repositories/organization_repository.dart';
import '../core/logging/app_logger.dart';

class NewWardCardPage extends StatefulWidget {
  const NewWardCardPage({super.key});
  static const String routeName = '/new-ward-card';

  @override
  State<NewWardCardPage> createState() => _NewWardCardPageState();
}

class _NewWardCardPageState extends State<NewWardCardPage> {
  final _formKey = GlobalKey<FormState>();

  // Personal data
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  String? _gender = 'male';

  // Diseases
  final Set<String> _selectedDiseases = {};
  final List<String> _diseases = [
    'Деменция',
    'Паркинсон',
    'Альцгеймер',
    'Инсульт',
    'Инфаркт',
    'Перелом шейки бедра',
  ];
  final TextEditingController _customDiseaseController =
      TextEditingController();
  String? _mobility = 'walks';

  // Services
  final Set<String> _selectedServices = {};
  final List<String> _services = [
    'Растирание конечностей',
    'Развивающие игры',
    'Интересный досуг',
    'Напоминать о приеме лекарств',
    'Помощь в кормлении',
    'Мерить давление',
    'Уборка',
    'Стирка',
    'Уколы',
    'Капельницы',
    'Лечение пролежней',
    'Перевязки',
  ];
  final TextEditingController _customServiceController =
      TextEditingController();
  final TextEditingController _customWishController = TextEditingController();
  final List<String> _wishes = [];

  // Expanded sections
  bool _isPersonalDataExpanded = false;
  bool _isDiseasesExpanded = false;
  bool _isServicesExpanded = false;

  // Loading state
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _birthDateController.dispose();
    _customDiseaseController.dispose();
    _customServiceController.dispose();
    _customWishController.dispose();
    super.dispose();
  }

  /// Парсинг ФИО в first_name, last_name, middle_name
  Map<String, String?> _parseFullName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return {
      'last_name': parts.isNotEmpty ? parts[0] : null,
      'first_name': parts.length > 1 ? parts[1] : null,
      'middle_name': parts.length > 2 ? parts.sublist(2).join(' ') : null,
    };
  }

  /// Парсинг даты рождения из формата ДД.ММ.ГГГГ в YYYY-MM-DD
  String? _parseBirthDate(String date) {
    if (date.isEmpty) return null;
    final parts = date.split('.');
    if (parts.length != 3) return null;
    final day = parts[0].padLeft(2, '0');
    final month = parts[1].padLeft(2, '0');
    final year = parts[2];
    return '$year-$month-$day';
  }

  /// Конвертация мобильности в формат API
  String? _getMobilityValue() {
    switch (_mobility) {
      case 'walks':
        return 'walking';
      case 'sits':
        return 'sitting';
      case 'lies':
        return 'bedridden';
      default:
        return null;
    }
  }

  Future<void> _saveCard(BuildContext blocContext) async {
    if (_formKey.currentState!.validate()) {
      // Парсим данные
      final nameParts = _parseFullName(_fullNameController.text);
      final birthDate = _parseBirthDate(_birthDateController.text);

      // Debug логирование
      log.debug(
        'Creating patient',
        context: LogContext.ui,
        extra: {
          'fullName': _fullNameController.text,
          'birthDateInput': _birthDateController.text,
          'birthDateParsed': birthDate,
        },
      );

      // Формируем данные для API
      final patientData = <String, dynamic>{
        'full_name': _fullNameController.text.trim(),
        'first_name': nameParts['first_name'],
        'last_name': nameParts['last_name'],
        'middle_name': nameParts['middle_name'],
        'birth_date': birthDate,
        'gender': _gender,
        'mobility': _getMobilityValue(),
        'diagnoses': _selectedDiseases.toList(),
        'needed_services': _selectedServices.toList(),
        'wishes': _wishes,
      };

      // ВРЕМЕННОЕ РЕШЕНИЕ: используем creator_id из текущего пользователя
      // TODO: Исправить на бэкенде - создавать запись в organizations при регистрации
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        final userId = int.tryParse(authState.user.id);
        if (userId != null) {
          // Сервер автоматически установит creator_id, но мы можем передать явно
          log.debug(
            'Patient will be linked to creator_id',
            context: LogContext.ui,
            extra: {'creator_id': userId},
          );
        }
      }

      // Попытка получить organization_id (если запись существует)
      try {
        final orgRepo = OrganizationRepository();
        final orgData = await orgRepo.getOrganization();
        final orgId = orgData['id'];
        if (orgId != null) {
          patientData['organization_id'] = orgId;
          log.debug(
            'Organization ID added',
            context: LogContext.ui,
            extra: {'orgId': orgId},
          );
        }
      } catch (e) {
        log.debug(
          'Organization not found (normal for new account)',
          context: LogContext.ui,
          error: e,
        );
        // Не критично - сервер всё равно установит creator_id
      }

      log.debug(
        'Patient data before cleanup',
        context: LogContext.ui,
        extra: {'data': patientData, 'wishes': _wishes},
      );

      // Убираем null значения
      patientData.removeWhere((key, value) => value == null);

      log.debug(
        'Patient data after cleanup',
        context: LogContext.ui,
        extra: {'data': patientData},
      );

      // Проверяем что context ещё mounted
      if (!mounted) return;

      // Отправляем на сервер
      blocContext.read<PatientBloc>().add(CreatePatient(patientData));
    }
  }

  Widget _buildExpandableSection({
    required String title,
    required String subtitle,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget content,
    required Color gradientStart,
    required Color gradientEnd,
    Color textColor = Colors.white,
    double bottomMargin = 12,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: bottomMargin),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradientStart, gradientEnd],
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
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: Radius.circular(isExpanded ? 0 : 16),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.firaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  if (!isExpanded) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: GoogleFonts.firaSans(
                        fontSize: 14,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Transform.rotate(
                    angle: isExpanded
                        ? -1.5708
                        : 1.5708, // -90° или 90° в радианах
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(textColor, BlendMode.srcIn),
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
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: content,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PatientBloc(),
      child: BlocListener<PatientBloc, PatientState>(
        listener: (context, state) {
          if (state is PatientLoading) {
            setState(() => _isLoading = true);
          } else {
            setState(() => _isLoading = false);
          }

          if (state is PatientCreated) {
            toastification.show(
              context: context,
              type: ToastificationType.success,
              style: ToastificationStyle.fillColored,
              title: const Text('Успешно'),
              description: const Text('Карточка пациента создана'),
              alignment: Alignment.topCenter,
              autoCloseDuration: const Duration(seconds: 3),
              borderRadius: BorderRadius.circular(12),
            );
            context.pop(state.patient);
          } else if (state is PatientError) {
            toastification.show(
              context: context,
              type: ToastificationType.error,
              style: ToastificationStyle.fillColored,
              title: const Text('Ошибка'),
              description: Text(state.message),
              alignment: Alignment.topCenter,
              autoCloseDuration: const Duration(seconds: 4),
              borderRadius: BorderRadius.circular(12),
            );
          }
        },
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
              'Новая карточка пациента',
              style: GoogleFonts.firaSans(
                color: Colors.grey.shade900,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: SafeArea(
            child: Form(
              key: _formKey,
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
                          Text(
                            'Заполните данные пациента',
                            style: GoogleFonts.firaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey.shade900,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Personal data section
                          _buildExpandableSection(
                            title: 'Личные данные',
                            subtitle:
                                'ФИО, дата рождения, адрес, пол, животные',
                            isExpanded: _isPersonalDataExpanded,
                            onTap: () {
                              setState(() {
                                _isPersonalDataExpanded =
                                    !_isPersonalDataExpanded;
                              });
                            },
                            gradientStart: const Color(0xFFA0E7E5),
                            gradientEnd: const Color(0xFF7DD3DC),
                            textColor: Colors.white,
                            bottomMargin: 0,
                            content: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'ФИО пациента',
                                  style: GoogleFonts.firaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _fullNameController,
                                  decoration: InputDecoration(
                                    hintText: 'Введите ФИО пациента',
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        12,
                                      ),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        12,
                                      ),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        12,
                                      ),
                                      borderSide: BorderSide(
                                        color: AppConfig.primaryColor,
                                      ),
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Введите ФИО пациента';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Дата рождения пациента',
                                  style: GoogleFonts.firaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _birthDateController,
                                  decoration: InputDecoration(
                                    hintText: 'ДД.ММ.ГГГГ',
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        12,
                                      ),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        12,
                                      ),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        12,
                                      ),
                                      borderSide: BorderSide(
                                        color: AppConfig.primaryColor,
                                      ),
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                    suffixIcon: Icon(
                                      Icons.calendar_today,
                                      color: Colors.grey.shade600,
                                      size: 20,
                                    ),
                                  ),
                                  keyboardType: TextInputType.datetime,
                                  inputFormatters: [
                                    MaskTextInputFormatter(
                                      mask: '##.##.####',
                                      filter: {'#': RegExp(r'[0-9]')},
                                    ),
                                  ],
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Введите дату рождения';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Выберите пол пациента',
                                  style: GoogleFonts.firaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _gender = 'male';
                                          });
                                        },
                                        child: Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                vertical: 12,
                                              ),
                                          decoration: BoxDecoration(
                                            color: _gender == 'male'
                                                ? AppConfig.primaryColor
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _gender == 'male'
                                                  ? AppConfig.primaryColor
                                                  : Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            'Мужской',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.firaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: _gender == 'male'
                                                  ? Colors.white
                                                  : Colors.grey.shade900,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _gender = 'female';
                                          });
                                        },
                                        child: Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                vertical: 12,
                                              ),
                                          decoration: BoxDecoration(
                                            color: _gender == 'female'
                                                ? AppConfig.primaryColor
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _gender == 'female'
                                                  ? AppConfig.primaryColor
                                                  : Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            'Женский',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.firaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: _gender == 'female'
                                                  ? Colors.white
                                                  : Colors.grey.shade900,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          AppConfig.primaryColor,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPersonalDataExpanded = false;
                                      });
                                    },
                                    child: Text(
                                      'Готово',
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
                          const SizedBox(height: 12),

                          // Diseases section
                          _buildExpandableSection(
                            title: 'Болезни',
                            subtitle:
                                'Деменция, паркинсон, инсульт, инфаркт и т.д.',
                            isExpanded: _isDiseasesExpanded,
                            bottomMargin: 0,
                            onTap: () {
                              setState(() {
                                _isDiseasesExpanded =
                                    !_isDiseasesExpanded;
                              });
                            },
                            gradientStart: const Color(0xFF5CBCC7),
                            gradientEnd: const Color(0xFF3D8A9C),
                            content: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Выберите болезни, если есть',
                                  style: GoogleFonts.firaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _diseases.map((disease) {
                                    final isSelected = _selectedDiseases
                                        .contains(disease);
                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedDiseases.remove(
                                              disease,
                                            );
                                          } else {
                                            _selectedDiseases.add(
                                              disease,
                                            );
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFFA0D9E3)
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFFA0D9E3)
                                                : Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Text(
                                          disease,
                                          style: GoogleFonts.firaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? const Color(0xFF4A4A4A)
                                                : Colors.grey.shade800,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                // Показываем кастомные диагнозы
                                if (_selectedDiseases.any(
                                  (d) => !_diseases.contains(d),
                                )) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'Добавленные болезни:',
                                    style: GoogleFonts.firaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ..._selectedDiseases
                                      .where(
                                        (d) => !_diseases.contains(d),
                                      )
                                      .map((disease) {
                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFFA0D9E3,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 14,
                                                      ),
                                                  child: Text(
                                                    disease,
                                                    style:
                                                        GoogleFonts.firaSans(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight
                                                                  .w600,
                                                          color:
                                                              const Color(
                                                                0xFF4A4A4A,
                                                              ),
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedDiseases
                                                        .remove(disease);
                                                  });
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(
                                                        12,
                                                      ),
                                                  child: Icon(
                                                    Icons.delete_outline,
                                                    size: 20,
                                                    color: Colors
                                                        .grey
                                                        .shade600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      })
                                      .toList(),
                                ],
                                const SizedBox(height: 16),
                                Text(
                                  'Добавить свою болезнь',
                                  style: GoogleFonts.firaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller:
                                            _customDiseaseController,
                                        decoration: InputDecoration(
                                          hintText:
                                              'Введите название болезни',
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: Colors.grey.shade200,
                                            ),
                                          ),
                                          enabledBorder:
                                              OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      12,
                                                    ),
                                                borderSide: BorderSide(
                                                  color: Colors
                                                      .grey
                                                      .shade200,
                                                ),
                                              ),
                                          focusedBorder:
                                              OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      12,
                                                    ),
                                                borderSide: BorderSide(
                                                  color: AppConfig
                                                      .primaryColor,
                                                ),
                                              ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 14,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () {
                                        if (_customDiseaseController
                                            .text
                                            .isNotEmpty) {
                                          setState(() {
                                            _selectedDiseases.add(
                                              _customDiseaseController
                                                  .text,
                                            );
                                            _customDiseaseController
                                                .clear();
                                          });
                                        }
                                      },
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: AppConfig.primaryColor,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Мобильность',
                                  style: GoogleFonts.firaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _mobility = 'walks';
                                          });
                                        },
                                        child: Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                vertical: 12,
                                              ),
                                          decoration: BoxDecoration(
                                            color: _mobility == 'walks'
                                                ? AppConfig.primaryColor
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(
                                                  100,
                                                ),
                                            border: Border.all(
                                              color: _mobility == 'walks'
                                                  ? AppConfig.primaryColor
                                                  : Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            'Ходит',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.firaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: _mobility == 'walks'
                                                  ? Colors.white
                                                  : Colors.grey.shade900,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _mobility = 'sits';
                                          });
                                        },
                                        child: Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                vertical: 12,
                                              ),
                                          decoration: BoxDecoration(
                                            color: _mobility == 'sits'
                                                ? AppConfig.primaryColor
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(
                                                  100,
                                                ),
                                            border: Border.all(
                                              color: _mobility == 'sits'
                                                  ? AppConfig.primaryColor
                                                  : Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            'Сидит',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.firaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: _mobility == 'sits'
                                                  ? Colors.white
                                                  : Colors.grey.shade900,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _mobility = 'lies';
                                          });
                                        },
                                        child: Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                vertical: 12,
                                              ),
                                          decoration: BoxDecoration(
                                            color: _mobility == 'lies'
                                                ? AppConfig.primaryColor
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(
                                                  100,
                                                ),
                                            border: Border.all(
                                              color: _mobility == 'lies'
                                                  ? AppConfig.primaryColor
                                                  : Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            'Лежит',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.firaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: _mobility == 'lies'
                                                  ? Colors.white
                                                  : Colors.grey.shade900,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          AppConfig.primaryColor,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isDiseasesExpanded = false;
                                      });
                                    },
                                    child: Text(
                                      'Готово',
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
                          const SizedBox(height: 12),

                          // Services section
                          _buildExpandableSection(
                            title: 'Требуемые услуги',
                            subtitle:
                                'Уколы, стирка, уборка, мерить давление и т.д.',
                            isExpanded: _isServicesExpanded,
                            onTap: () {
                              setState(() {
                                _isServicesExpanded =
                                    !_isServicesExpanded;
                              });
                            },
                            gradientStart: const Color(0xFF3D8A9C),
                            gradientEnd: const Color(0xFF2A6B7A),
                            content: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _services.map((service) {
                                    final isSelected = _selectedServices
                                        .contains(service);
                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedServices.remove(
                                              service,
                                            );
                                          } else {
                                            _selectedServices.add(
                                              service,
                                            );
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFFA0D9E3)
                                              : Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          service,
                                          style: GoogleFonts.firaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? const Color(0xFF4A4A4A)
                                                : Colors.grey.shade800,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                // Показываем кастомные услуги
                                if (_selectedServices.any(
                                  (s) => !_services.contains(s),
                                )) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'Добавленные услуги:',
                                    style: GoogleFonts.firaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ..._selectedServices
                                      .where(
                                        (s) => !_services.contains(s),
                                      )
                                      .map((service) {
                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFFA0D9E3,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 14,
                                                      ),
                                                  child: Text(
                                                    service,
                                                    style:
                                                        GoogleFonts.firaSans(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight
                                                                  .w600,
                                                          color: Colors
                                                              .white,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedServices
                                                        .remove(service);
                                                  });
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(
                                                        12,
                                                      ),
                                                  child: const Icon(
                                                    Icons.delete_outline,
                                                    size: 20,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      })
                                      .toList(),
                                ],
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller:
                                            _customServiceController,
                                        decoration: InputDecoration(
                                          hintText:
                                              'Добавить свою услугу',
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: Colors.grey.shade200,
                                            ),
                                          ),
                                          enabledBorder:
                                              OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      12,
                                                    ),
                                                borderSide: BorderSide(
                                                  color: Colors
                                                      .grey
                                                      .shade200,
                                                ),
                                              ),
                                          focusedBorder:
                                              OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      12,
                                                    ),
                                                borderSide: BorderSide(
                                                  color: AppConfig
                                                      .primaryColor,
                                                ),
                                              ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 14,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () {
                                        if (_customServiceController
                                            .text
                                            .isNotEmpty) {
                                          setState(() {
                                            _selectedServices.add(
                                              _customServiceController
                                                  .text,
                                            );
                                            _customServiceController
                                                .clear();
                                          });
                                        }
                                      },
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: AppConfig.primaryColor,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // Показываем добавленные пожелания
                                if (_wishes.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'Добавленные пожелания:',
                                    style: GoogleFonts.firaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ..._wishes.map((wish) {
                                    return Container(
                                      margin: const EdgeInsets.only(
                                        bottom: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFA0D9E3),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 14,
                                                  ),
                                              child: Text(
                                                wish,
                                                style:
                                                    GoogleFonts.firaSans(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              setState(() {
                                                _wishes.remove(wish);
                                              });
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.all(
                                                    12,
                                                  ),
                                              child: const Icon(
                                                Icons.delete_outline,
                                                size: 20,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _customWishController,
                                        decoration: InputDecoration(
                                          hintText: 'Добавить пожелание',
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: Colors.grey.shade200,
                                            ),
                                          ),
                                          enabledBorder:
                                              OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      12,
                                                    ),
                                                borderSide: BorderSide(
                                                  color: Colors
                                                      .grey
                                                      .shade200,
                                                ),
                                              ),
                                          focusedBorder:
                                              OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      12,
                                                    ),
                                                borderSide: BorderSide(
                                                  color: AppConfig
                                                      .primaryColor,
                                                ),
                                              ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 14,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () {
                                        if (_customWishController
                                            .text
                                            .isNotEmpty) {
                                          setState(() {
                                            _wishes.add(
                                              _customWishController.text,
                                            );
                                            _customWishController.clear();
                                          });
                                        }
                                      },
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: AppConfig.primaryColor,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          AppConfig.primaryColor,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isServicesExpanded = false;
                                      });
                                    },
                                    child: Text(
                                      'Готово',
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
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  // Save button
                  Builder(
                    builder: (blocContext) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: InkWell(
                            onTap: _isLoading
                                ? null
                                : () => _saveCard(blocContext),
                            borderRadius: BorderRadius.circular(100),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _isLoading
                                        ? AppConfig.primaryColor.withOpacity(
                                            0.6,
                                          )
                                        : AppConfig.primaryColor,
                                    _isLoading
                                        ? AppConfig.primaryColor.withOpacity(
                                            0.5,
                                          )
                                        : AppConfig.primaryColor.withOpacity(
                                            0.8,
                                          ),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: _isLoading
                                  ? const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      ),
                                    )
                                  : Text(
                                      'Сохранить',
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
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
