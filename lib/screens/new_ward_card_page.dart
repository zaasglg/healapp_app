import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../config/app_config.dart';
import '../utils/app_icons.dart';

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
  String? _gender;

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
  String? _mobility;

  // Services
  final Set<String> _selectedServices = {};
  final List<String> _services = [
    'Растирание конечностей',
    'Развивающие игры',
    'Интересный досуг',
    'Напоминать о приеме лекарств',
    'Помощь в кормлении',
    'Мерять давление',
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

  // Expanded sections
  bool _isPersonalDataExpanded = false;
  bool _isDiseasesExpanded = false;
  bool _isServicesExpanded = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _birthDateController.dispose();
    _customDiseaseController.dispose();
    _customServiceController.dispose();
    _customWishController.dispose();
    super.dispose();
  }

  void _saveCard() {
    if (_formKey.currentState!.validate()) {
      // TODO: Implement save functionality
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Карточка сохранена'),
          duration: Duration(seconds: 2),
        ),
      );
      context.pop();
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
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                        subtitle: 'ФИО, дата рождения, адрес, пол, животные',
                        isExpanded: _isPersonalDataExpanded,
                        onTap: () {
                          setState(() {
                            _isPersonalDataExpanded = !_isPersonalDataExpanded;
                          });
                        },
                        gradientStart: const Color(0xFFA0E7E5),
                        gradientEnd: const Color(0xFF7DD3DC),
                        textColor: Colors.grey.shade900,
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
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppConfig.primaryColor,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
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
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppConfig.primaryColor,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
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
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _gender == 'male'
                                            ? AppConfig.primaryColor
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
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
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _gender == 'female'
                                            ? AppConfig.primaryColor
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
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
                                  backgroundColor: AppConfig.primaryColor,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
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

                      // Diseases section
                      _buildExpandableSection(
                        title: 'Болезни',
                        subtitle:
                            'Деменция, паркинсон, инсульт, инфаркт и т.д.',
                        isExpanded: _isDiseasesExpanded,
                        onTap: () {
                          setState(() {
                            _isDiseasesExpanded = !_isDiseasesExpanded;
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
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _diseases.map((disease) {
                                final isSelected = _selectedDiseases.contains(
                                  disease,
                                );
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedDiseases.remove(disease);
                                      } else {
                                        _selectedDiseases.add(disease);
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppConfig.primaryColor
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppConfig.primaryColor
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      disease,
                                      style: GoogleFonts.firaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _customDiseaseController,
                                    decoration: InputDecoration(
                                      hintText: 'Добавить болезнь не из списка',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
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
                                          _customDiseaseController.text,
                                        );
                                        _customDiseaseController.clear();
                                      });
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
                                color: Colors.white,
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
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _mobility == 'walks'
                                            ? AppConfig.primaryColor
                                            : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                        border: _mobility == 'walks'
                                            ? null
                                            : Border.all(
                                                color: Colors.grey.shade300,
                                                width: 1,
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
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _mobility == 'sits'
                                            ? AppConfig.primaryColor
                                            : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                        border: _mobility == 'sits'
                                            ? null
                                            : Border.all(
                                                color: Colors.grey.shade300,
                                                width: 1,
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
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _mobility == 'lies'
                                            ? AppConfig.primaryColor
                                            : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                        border: _mobility == 'lies'
                                            ? null
                                            : Border.all(
                                                color: Colors.grey.shade300,
                                                width: 1,
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
                                  backgroundColor: AppConfig.primaryColor,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
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

                      // Services section
                      _buildExpandableSection(
                        title: 'Требуемые услуги',
                        subtitle:
                            'Уколы, стирка, уборка, мерять давление и т.д.',
                        isExpanded: _isServicesExpanded,
                        onTap: () {
                          setState(() {
                            _isServicesExpanded = !_isServicesExpanded;
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
                                final isSelected = _selectedServices.contains(
                                  service,
                                );
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedServices.remove(service);
                                      } else {
                                        _selectedServices.add(service);
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppConfig.primaryColor
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      service,
                                      style: GoogleFonts.firaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _customServiceController,
                                    decoration: InputDecoration(
                                      hintText: 'Добавить свою услугу',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
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
                                          _customServiceController.text,
                                        );
                                        _customServiceController.clear();
                                      });
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
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
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
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    if (_customWishController.text.isNotEmpty) {
                                      // TODO: Handle custom wish
                                      _customWishController.clear();
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
                                  backgroundColor: AppConfig.primaryColor,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: InkWell(
                    onTap: _saveCard,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
