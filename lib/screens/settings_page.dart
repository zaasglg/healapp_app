import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';
import 'package:toastification/toastification.dart';
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';
import '../utils/app_icons.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/auth/auth_state.dart';
import '../bloc/organization/organization_bloc.dart';
import '../bloc/organization/organization_event.dart';
import '../bloc/organization/organization_state.dart';
import '../core/network/api_client.dart';
import '../repositories/auth_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  static const String routeName = '/settings';

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final MaskTextInputFormatter _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {"#": RegExp(r'\d')},
  );

  // Контроллеры для организации
  late TextEditingController _organizationNameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  // Контроллеры для частной сиделки
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  String? _selectedCity;

  bool _isInitialized = false;
  String? _previousAvatarUrl;
  User? _cachedUser;

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
    _organizationNameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();

    // Загружаем данные при открытии страницы
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        _previousAvatarUrl = authState.user.avatar;
        _cachedUser = authState.user;

        // Инициализируем форму для сиделки или клиента из данных пользователя
        if (authState.user.accountType == 'specialist' ||
            authState.user.accountType == 'doctor' ||
            authState.user.accountType == 'caregiver') {
          _firstNameController.text = authState.user.firstName ?? '';
          _lastNameController.text = authState.user.lastName ?? '';
          final currentCity =
              authState.user.additionalData?['city']?.toString() ?? '';
          // Устанавливаем выбранный город, если он есть в списке
          if (currentCity.isNotEmpty && _russianCities.contains(currentCity)) {
            _selectedCity = currentCity;
          }
          _isInitialized = true;
        } else if ((authState.user.accountType == 'pansionat' ||
                authState.user.accountType == 'agency') &&
            (authState.user.firstName != null ||
                authState.user.lastName != null)) {
          // Для пансионата с именем и фамилией показываем персональные поля
          _firstNameController.text = authState.user.firstName ?? '';
          _lastNameController.text = authState.user.lastName ?? '';
          _isInitialized = true;
        } else {
          // Загружаем данные организации только для организаций (не для specialist/client)
          context.read<OrganizationBloc>().add(
            const LoadOrganizationRequested(),
          );
        }
      }
      // Обновляем данные пользователя
      context.read<AuthBloc>().add(const AuthRefreshUser());
    });
  }

  @override
  void dispose() {
    _organizationNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  /// Инициализация полей формы из данных организации
  void _initializeFromOrganization(Map<String, dynamic> organization) {
    _organizationNameController.text = organization['name']?.toString() ?? '';

    // Форматируем телефон
    final phone = organization['phone']?.toString() ?? '';
    if (phone.isNotEmpty) {
      // Убираем все нечисловые символы и применяем маску
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (cleanPhone.length == 10) {
        _phoneMask.formatEditUpdate(
          const TextEditingValue(text: ''),
          TextEditingValue(text: cleanPhone),
        );
        _phoneController.text = _phoneMask.getMaskedText();
      } else if (cleanPhone.length == 11 && cleanPhone.startsWith('7')) {
        _phoneMask.formatEditUpdate(
          const TextEditingValue(text: ''),
          TextEditingValue(text: cleanPhone.substring(1)),
        );
        _phoneController.text = _phoneMask.getMaskedText();
      } else {
        _phoneController.text = phone;
      }
    }

    _addressController.text = organization['address']?.toString() ?? '';
    _isInitialized = true;
  }

  String _getAccountTypeLabel(String? accountType) {
    switch (accountType) {
      case 'pansionat':
        return 'Пансионат';
      case 'agency':
        return 'Агентство';
      case 'specialist':
        return 'Частная сиделка';
      case 'client':
        return 'Клиент';
      default:
        return 'Организация';
    }
  }

  /// Выбор изображения для аватара
  Future<void> _pickAvatar() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        // Проверяем размер файла (максимум 5MB)
        // Для веба используем readAsBytes(), для мобильных - File
        final fileSizeInBytes = await image.length();
        const maxSizeInBytes = 5 * 1024 * 1024; // 5MB

        if (fileSizeInBytes > maxSizeInBytes) {
          if (mounted) {
            toastification.show(
              context: context,
              type: ToastificationType.error,
              style: ToastificationStyle.fillColored,
              title: const Text('Ошибка'),
              description: const Text('Размер файла не должен превышать 5MB'),
              alignment: Alignment.topCenter,
              autoCloseDuration: const Duration(seconds: 3),
            );
          }
          return;
        }

        // Загружаем аватар через BLoC
        if (mounted) {
          context.read<AuthBloc>().add(
            AuthUploadAvatarRequested(filePath: image.path),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          title: const Text('Ошибка'),
          description: Text('Не удалось выбрать изображение: $e'),
          alignment: Alignment.topCenter,
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  /// Виджет для отображения аватара
  Widget _buildAvatar(String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      // Преобразуем относительный путь в полный URL
      final fullUrl = ApiConfig.getFullUrl(avatarUrl);

      return ClipOval(
        child: Image.network(
          fullUrl,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                AppIcons.profile,
                width: 60,
                height: 60,
                fit: BoxFit.contain,
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                  color: AppConfig.primaryColor,
                ),
              ),
            );
          },
        ),
      );
    }

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        shape: BoxShape.circle,
      ),
      child: SvgPicture.asset(
        AppIcons.profile,
        width: 60,
        height: 60,
        fit: BoxFit.contain,
      ),
    );
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
    );
  }

  void _submitOrganization() {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();
      final phone = _phoneMask.getUnmaskedText();

      context.read<OrganizationBloc>().add(
        UpdateOrganizationRequested(
          name: _organizationNameController.text.trim(),
          phone: phone,
          address: _addressController.text.trim(),
        ),
      );
    }
  }

  void _submitCaregiver() {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();

      context.read<AuthBloc>().add(
        AuthUpdateProfileRequested(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          city: _selectedCity ?? '',
        ),
      );
    }
  }

  /// Shimmer эффект для загрузки формы
  Widget _buildShimmerLoading() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar placeholder
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 100,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Organization name field
            Container(
              width: 140,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),

            // Phone field
            Container(
              width: 120,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),

            // Address field
            Container(
              width: 130,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated) {
              _cachedUser = state.user;
              // Проверяем, изменился ли аватар
              final currentAvatarUrl = state.user.avatar;
              if (_previousAvatarUrl != currentAvatarUrl &&
                  currentAvatarUrl != null &&
                  currentAvatarUrl.isNotEmpty &&
                  _previousAvatarUrl != null) {
                // Аватар был обновлен
                toastification.show(
                  context: context,
                  type: ToastificationType.success,
                  style: ToastificationStyle.fillColored,
                  title: const Text('Успешно'),
                  description: const Text('Аватар успешно загружен'),
                  alignment: Alignment.topCenter,
                  autoCloseDuration: const Duration(seconds: 3),
                  borderRadius: BorderRadius.circular(12),
                );
              }
              _previousAvatarUrl = currentAvatarUrl;
            } else if (state is AuthUnauthenticated) {
              _cachedUser = null;
              context.go('/login');
            } else if (state is AuthFailure) {
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
        ),
        BlocListener<OrganizationBloc, OrganizationState>(
          listener: (context, state) {
            // Инициализируем поля формы при загрузке данных организации
            if (state is OrganizationLoaded && !_isInitialized) {
              _initializeFromOrganization(state.organization);
            } else if (state is OrganizationUpdated) {
              // Показываем тост при успешном обновлении
              toastification.show(
                context: context,
                type: ToastificationType.success,
                style: ToastificationStyle.fillColored,
                title: const Text('Успешно'),
                description: const Text('Изменения сохранены'),
                alignment: Alignment.topCenter,
                autoCloseDuration: const Duration(seconds: 3),
                borderRadius: BorderRadius.circular(12),
              );

              // Обновляем данные пользователя в AuthBloc
              context.read<AuthBloc>().add(const AuthRefreshUser());
            } else if (state is OrganizationFailure) {
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
        ),
      ],
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          final effectiveUser = authState is AuthAuthenticated
              ? authState.user
              : _cachedUser;
          final accountType = effectiveUser?.accountType;

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
                'Настройки',
                style: GoogleFonts.firaSans(
                  color: Colors.grey.shade900,
                  fontWeight: FontWeight.w700,
                ),
              ),
              centerTitle: true,
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      'Редактирование профиля',
                      style: GoogleFonts.firaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, authState) {
                        final user = authState is AuthAuthenticated
                            ? authState.user
                            : _cachedUser;
                        String roleLabel = _getAccountTypeLabel(accountType);

                        // Если пользователь авторизован, показываем его роль
                        if (user != null) {
                          if (user.hasRole('caregiver')) {
                            roleLabel = 'Сиделка';
                          } else if (user.hasRole('doctor')) {
                            roleLabel = 'Врач';
                          } else if (user.hasRole('admin')) {
                            roleLabel = 'Администратор';
                          } else if (user.accountType == 'specialist') {
                            roleLabel = 'Частная сиделка';
                          } else if (user.accountType == 'client') {
                            roleLabel = 'Клиент';
                          }
                        }

                        return Center(
                          child: Text(
                            roleLabel,
                            style: GoogleFonts.firaSans(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Form with shimmer loading
                    BlocBuilder<OrganizationBloc, OrganizationState>(
                      builder: (context, orgState) {
                        // Показываем shimmer при загрузке и если форма еще не инициализирована
                        if (orgState is OrganizationLoading &&
                            !_isInitialized) {
                          return _buildShimmerLoading();
                        }

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                BlocBuilder<AuthBloc, AuthState>(
                                  builder: (context, authState) {
                                    final user = authState is AuthAuthenticated
                                        ? authState.user
                                        : _cachedUser;
                                    final avatarUrl = user?.avatar;

                                    return Center(
                                      child: Column(
                                        children: [
                                          GestureDetector(
                                            onTap: _pickAvatar,
                                            child: _buildAvatar(avatarUrl),
                                          ),
                                          const SizedBox(height: 5),
                                          TextButton(
                                            onPressed: _pickAvatar,
                                            child: Text(
                                              'Выбрать аватар',
                                              style: GoogleFonts.firaSans(
                                                fontSize: 14,
                                                color: AppConfig.primaryColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),

                                // Форма зависит от типа аккаунта
                                BlocBuilder<AuthBloc, AuthState>(
                                  builder: (context, authState) {
                                    final user = authState is AuthAuthenticated
                                        ? authState.user
                                        : _cachedUser;
                                    final accountType = user?.accountType;

                                    // Проверяем, является ли это персональным аккаунтом
                                    // Для пансионата проверяем наличие имени или фамилии
                                    final isPersonalAccount =
                                        accountType == 'specialist' ||
                                        accountType == 'doctor' ||
                                        accountType == 'caregiver' ||
                                        accountType == 'agency' ||
                                        (accountType == 'pansionat' &&
                                            (user?.firstName != null ||
                                                user?.lastName != null));

                                    final isSpecialist =
                                        accountType == 'specialist';

                                    if (isPersonalAccount) {
                                      // Форма для частной сиделки или клиента
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Имя',
                                            style: GoogleFonts.firaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade900,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _firstNameController,
                                            decoration: _inputDecoration(
                                              'Введите имя',
                                            ),
                                            textCapitalization:
                                                TextCapitalization.words,
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty)
                                                ? 'Укажите имя'
                                                : null,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Фамилия',
                                            style: GoogleFonts.firaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade900,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _lastNameController,
                                            decoration: _inputDecoration(
                                              'Введите фамилию',
                                            ),
                                            textCapitalization:
                                                TextCapitalization.words,
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty)
                                                ? 'Укажите фамилию'
                                                : null,
                                          ),
                                          // Город только для частной сиделки
                                          if (isSpecialist) ...[
                                            const SizedBox(height: 16),
                                            Text(
                                              'Город',
                                              style: GoogleFonts.firaSans(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade900,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            TextFormField(
                                              readOnly: true,
                                              decoration:
                                                  _inputDecoration(
                                                    'Выберите город',
                                                  ).copyWith(
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
                                                  (v == null ||
                                                      v.trim().isEmpty)
                                                  ? 'Выберите город'
                                                  : null,
                                            ),
                                          ],
                                          const SizedBox(height: 24),
                                          BlocBuilder<AuthBloc, AuthState>(
                                            builder: (context, state) {
                                              final isLoading =
                                                  state is AuthLoading;

                                              return SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        AppConfig.primaryColor,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 16,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                    ),
                                                    elevation: 0,
                                                    disabledBackgroundColor:
                                                        AppConfig.primaryColor
                                                            .withValues(
                                                              alpha: 0.6,
                                                            ),
                                                  ),
                                                  onPressed: isLoading
                                                      ? null
                                                      : _submitCaregiver,
                                                  child: isLoading
                                                      ? const SizedBox(
                                                          height: 20,
                                                          width: 20,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                  Color
                                                                >(Colors.white),
                                                          ),
                                                        )
                                                      : Text(
                                                          'Сохранить изменения',
                                                          style:
                                                              GoogleFonts.firaSans(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                        ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      );
                                    } else {
                                      // Форма для организации
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Название организации',
                                            style: GoogleFonts.firaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade900,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller:
                                                _organizationNameController,
                                            decoration: _inputDecoration(
                                              'Название организации',
                                            ),
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty)
                                                ? 'Укажите название организации'
                                                : null,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Номер телефона',
                                            style: GoogleFonts.firaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade900,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _phoneController,
                                            keyboardType: TextInputType.phone,
                                            decoration: _inputDecoration(
                                              'Номер телефона',
                                            ),
                                            inputFormatters: [_phoneMask],
                                            validator: (v) =>
                                                (_phoneMask
                                                        .getUnmaskedText()
                                                        .length !=
                                                    10)
                                                ? 'Введите корректный номер телефона'
                                                : null,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Номер телефона нужен для связи с поддержкой в WhatsApp',
                                            style: GoogleFonts.firaSans(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Адрес организации',
                                            style: GoogleFonts.firaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade900,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _addressController,
                                            decoration: _inputDecoration(
                                              'Введите адрес места нахождения организации',
                                            ),
                                            maxLines: 3,
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty)
                                                ? 'Укажите адрес организации'
                                                : null,
                                          ),
                                          const SizedBox(height: 24),
                                          BlocBuilder<
                                            OrganizationBloc,
                                            OrganizationState
                                          >(
                                            builder: (context, orgState) {
                                              final isLoading =
                                                  orgState
                                                      is OrganizationLoading;

                                              return SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        AppConfig.primaryColor,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 16,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                    ),
                                                    elevation: 0,
                                                    disabledBackgroundColor:
                                                        AppConfig.primaryColor
                                                            .withValues(
                                                              alpha: 0.6,
                                                            ),
                                                  ),
                                                  onPressed: isLoading
                                                      ? null
                                                      : _submitOrganization,
                                                  child: isLoading
                                                      ? const SizedBox(
                                                          height: 20,
                                                          width: 20,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                  Color
                                                                >(Colors.white),
                                                          ),
                                                        )
                                                      : Text(
                                                          'Сохранить изменения',
                                                          style:
                                                              GoogleFonts.firaSans(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                        ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Logout button
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        final bool isLoading = state is AuthLoading;
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(54),
                              ),
                              elevation: 0,
                            ),
                            onPressed: isLoading
                                ? null
                                : () => context.read<AuthBloc>().add(
                                    const AuthLogoutRequested(),
                                  ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    'Выйти из аккаунта',
                                    style: GoogleFonts.firaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
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
