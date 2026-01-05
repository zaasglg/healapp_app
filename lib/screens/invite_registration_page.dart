import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../config/app_config.dart';
import '../repositories/invitation_repository.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../utils/app_logger.dart';

/// Страница регистрации сотрудника по приглашению
class InviteRegistrationPage extends StatefulWidget {
  final String token;

  const InviteRegistrationPage({super.key, required this.token});

  @override
  State<InviteRegistrationPage> createState() => _InviteRegistrationPageState();
}

class _InviteRegistrationPageState extends State<InviteRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingInvitation = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Invitation? _invitation;
  String? _error;

  final _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    _loadInvitation();
  }

  Future<void> _loadInvitation() async {
    try {
      setState(() {
        _isLoadingInvitation = true;
        _error = null;
      });

      final invitation = await invitationRepository.getInvitation(widget.token);

      setState(() {
        _invitation = invitation;
        _isLoadingInvitation = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoadingInvitation = false;
      });
    } catch (e) {
      log.e('Ошибка загрузки приглашения: $e');
      setState(() {
        _error = 'Не удалось загрузить приглашение';
        _isLoadingInvitation = false;
      });
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.firaSans(
        fontSize: 16,
        color: Colors.grey.shade400,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppConfig.primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final phone = _phoneMask.getUnmaskedText();
      final password = _passwordController.text;
      final passwordConfirmation = _confirmPasswordController.text;

      final result = await invitationRepository.acceptInvitation(
        token: widget.token,
        phone: phone,
        password: password,
        passwordConfirmation: passwordConfirmation,
        firstName: firstName.isNotEmpty ? firstName : null,
        lastName: lastName.isNotEmpty ? lastName : null,
      );

      // Сохраняем токен через API клиент
      await apiClient.saveToken(result.accessToken);

      log.i('Регистрация успешна: ${result.message}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green,
          ),
        );

        // Переходим на главную страницу
        context.go('/profile');
      }
    } on ValidationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.getAllErrors().join('\n')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      log.e('Ошибка регистрации: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Произошла ошибка'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.primaryColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Верхний синий блок с отступом
            const SizedBox(height: 60),

            // Белая карточка с формой
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
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoadingInvitation) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return _buildForm();
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red.shade400),
          const SizedBox(height: 24),
          Text(
            _error!,
            style: GoogleFonts.firaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Попросите администратора создать новое приглашение',
            style: GoogleFonts.firaSans(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.go('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConfig.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Перейти к входу',
              style: GoogleFonts.firaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Center(
              child: Text(
                'Регистрация сотрудника',
                style: GoogleFonts.firaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),

            // Подзаголовок
            Center(
              child: Text(
                'Введите номер телефона и придумайте пароль, чтобы получить доступ к дневникам организации.',
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 28),

            // Поле имени
            Text(
              'Имя',
              style: GoogleFonts.firaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _firstNameController,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.firaSans(
                fontSize: 16,
                color: Colors.grey.shade800,
              ),
              decoration: _inputDecoration('Введите ваше имя'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введите имя';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Поле фамилии
            Text(
              'Фамилия',
              style: GoogleFonts.firaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _lastNameController,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.firaSans(
                fontSize: 16,
                color: Colors.grey.shade800,
              ),
              decoration: _inputDecoration('Введите вашу фамилию'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введите фамилию';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Поле телефона
            Text(
              'Введите номер телефона',
              style: GoogleFonts.firaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              inputFormatters: [_phoneMask],
              keyboardType: TextInputType.phone,
              style: GoogleFonts.firaSans(
                fontSize: 16,
                color: Colors.grey.shade800,
              ),
              decoration: _inputDecoration('Номер телефона'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите номер телефона';
                }
                if (_phoneMask.getUnmaskedText().length < 10) {
                  return 'Введите корректный номер';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Поле пароля
            Text(
              'Придумайте пароль',
              style: GoogleFonts.firaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: GoogleFonts.firaSans(
                fontSize: 16,
                color: Colors.grey.shade800,
              ),
              decoration: _inputDecoration('Пароль').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey.shade400,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите пароль';
                }
                if (value.length < 6) {
                  return 'Минимум 6 символов';
                }
                return null;
              },
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Минимум 6 символов',
                style: GoogleFonts.firaSans(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Подтверждение пароля
            Text(
              'Подтвердите пароль',
              style: GoogleFonts.firaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              style: GoogleFonts.firaSans(
                fontSize: 16,
                color: Colors.grey.shade800,
              ),
              decoration: _inputDecoration('Повторите пароль').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.grey.shade400,
                  ),
                  onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Подтвердите пароль';
                }
                if (value != _passwordController.text) {
                  return 'Пароли не совпадают';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Кнопка регистрации
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleRegistration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConfig.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: AppConfig.primaryColor.withOpacity(
                    0.6,
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Завершить регистрацию',
                        style: GoogleFonts.firaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Ссылка на вход
            Center(
              child: TextButton(
                onPressed: () => context.go('/login'),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Уже есть аккаунт? ',
                        style: GoogleFonts.firaSans(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      TextSpan(
                        text: 'Войти',
                        style: GoogleFonts.firaSans(
                          decoration: TextDecoration.underline,
                          color: AppConfig.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
