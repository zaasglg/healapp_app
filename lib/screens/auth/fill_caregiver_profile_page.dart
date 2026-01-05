import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_config.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../utils/app_logger.dart';

class FillCaregiverProfilePage extends StatefulWidget {
  const FillCaregiverProfilePage({super.key});
  static const String routeName = '/fill-caregiver-profile';

  @override
  State<FillCaregiverProfilePage> createState() =>
      _FillCaregiverProfilePageState();
}

class _FillCaregiverProfilePageState extends State<FillCaregiverProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  String? _selectedCity;

  // Список городов России (основные города)
  static const List<String> _russianCities = [
    'Абакан',
    'Анадырь',
    'Архангельск',
    'Астрахань',
    'Барнаул',
    'Белгород',
    'Биробиджан',
    'Благовещенск',
    'Брянск',
    'Великий Новгород',
    'Владивосток',
    'Владикавказ',
    'Владимир',
    'Волгоград',
    'Вологда',
    'Воронеж',
    'Горно-Алтайск',
    'Грозный',
    'Екатеринбург',
    'Иваново',
    'Ижевск',
    'Иркутск',
    'Йошкар-Ола',
    'Казань',
    'Калининград',
    'Калуга',
    'Кемерово',
    'Киров',
    'Кострома',
    'Краснодар',
    'Красноярск',
    'Курган',
    'Курск',
    'Кызыл',
    'Липецк',
    'Магадан',
    'Магас',
    'Майкоп',
    'Махачкала',
    'Москва',
    'Мурманск',
    'Нальчик',
    'Нарьян-Мар',
    'Нижний Новгород',
    'Новгород',
    'Новосибирск',
    'Омск',
    'Орёл',
    'Оренбург',
    'Пенза',
    'Пермь',
    'Петрозаводск',
    'Петропавловск-Камчатский',
    'Псков',
    'Ростов-на-Дону',
    'Рязань',
    'Салехард',
    'Самара',
    'Санкт-Петербург',
    'Саранск',
    'Саратов',
    'Севастополь',
    'Симферополь',
    'Смоленск',
    'Ставрополь',
    'Сыктывкар',
    'Тамбов',
    'Тверь',
    'Томск',
    'Тула',
    'Тюмень',
    'Улан-Удэ',
    'Ульяновск',
    'Уфа',
    'Хабаровск',
    'Ханты-Мансийск',
    'Чебоксары',
    'Челябинск',
    'Черкесск',
    'Чита',
    'Элиста',
    'Южно-Сахалинск',
    'Якутск',
    'Ярославль',
  ];

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppConfig.primaryColor),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final city = _selectedCity ?? '';

      log.d('Отправка данных профиля сиделки:');
      log.d('firstName: $firstName, lastName: $lastName, city: $city');

      // Обновляем данные пользователя через AuthBloc
      context.read<AuthBloc>().add(
        AuthUpdateProfileRequested(
          firstName: firstName,
          lastName: lastName,
          city: city,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // Навигация при успешном обновлении
        if (state is AuthAuthenticated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Профиль обновлён'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Переход на страницу дневников
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              context.go('/diaries');
            }
          });
        }

        // Показ ошибки при неудаче
        if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppConfig.primaryColor,
        body: Column(
          children: [
            const SizedBox(height: 60),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28.0,
                    vertical: 24,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Заполнить профиль',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.firaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Частная сиделка',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.firaSans(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Имя',
                                style: GoogleFonts.firaSans(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _firstNameController,
                                decoration: _inputDecoration('Введите имя'),
                                textCapitalization: TextCapitalization.words,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Укажите имя'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Фамилия',
                                style: GoogleFonts.firaSans(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _lastNameController,
                                decoration: _inputDecoration('Введите фамилию'),
                                textCapitalization: TextCapitalization.words,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Укажите фамилию'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Город',
                                style: GoogleFonts.firaSans(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                readOnly: true,
                                decoration: _inputDecoration('Выберите город')
                                    .copyWith(
                                      suffixIcon: const Icon(
                                        Icons.arrow_drop_down,
                                      ),
                                    ),
                                controller: TextEditingController(
                                  text: _selectedCity ?? '',
                                ),
                                onTap: () async {
                                  final selected =
                                      await _showCitySearchDialog();
                                  if (selected != null) {
                                    setState(() {
                                      _selectedCity = selected;
                                    });
                                  }
                                },
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Выберите город'
                                    : null,
                              ),
                              const SizedBox(height: 24),
                              BlocBuilder<AuthBloc, AuthState>(
                                builder: (context, state) {
                                  final isLoading = state is AuthLoading;

                                  return ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppConfig.primaryColor,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      disabledBackgroundColor: AppConfig
                                          .primaryColor
                                          .withValues(alpha: 0.6),
                                    ),
                                    onPressed: isLoading ? null : _submit,
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : Text(
                                            'Сохранить профиль',
                                            style: GoogleFonts.firaSans(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
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

  /// Показывает диалог поиска города
  Future<String?> _showCitySearchDialog() async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return _CitySearchDialog(cities: _russianCities);
      },
    );
  }
}

/// Диалог для поиска города
class _CitySearchDialog extends StatefulWidget {
  final List<String> cities;

  const _CitySearchDialog({required this.cities});

  @override
  State<_CitySearchDialog> createState() => _CitySearchDialogState();
}

class _CitySearchDialogState extends State<_CitySearchDialog> {
  late List<String> _filteredCities;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredCities = widget.cities;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCities(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCities = widget.cities;
      } else {
        _filteredCities = widget.cities
            .where((city) => city.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Выберите город',
                      style: GoogleFonts.firaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Поиск города...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filterCities('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: _filterCities,
              ),
            ),
            const SizedBox(height: 8),
            // City list
            Flexible(
              child: _filteredCities.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Город не найден',
                          style: GoogleFonts.firaSans(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredCities.length,
                      itemBuilder: (context, index) {
                        final city = _filteredCities[index];
                        return ListTile(
                          title: Text(
                            city,
                            style: GoogleFonts.firaSans(fontSize: 16),
                          ),
                          onTap: () => Navigator.of(context).pop(city),
                          dense: true,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
