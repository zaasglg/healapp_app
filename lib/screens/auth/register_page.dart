import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:toastification/toastification.dart';
import '../../config/app_config.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';

enum Role { nursingHome, agency, privateCaregiver }

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  static const String routeName = '/register';

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final MaskTextInputFormatter _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {"#": RegExp(r'\d')},
  );
  final TextEditingController _passwordController = TextEditingController();

  String _password = '';
  String _passwordConfirmation = '';
  int _step = 0; // 0 = choose role, 1 = fill details
  Role? _selectedRole;

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
    );
  }

  /// Получить account_type на основе выбранного Role
  String _getAccountType(Role role) {
    switch (role) {
      case Role.nursingHome:
        return 'pansionat';
      case Role.agency:
        return 'agency';
      case Role.privateCaregiver:
        return 'specialist';
    }
  }

  /// Получить читаемое название роли
  String _getRoleName(Role role) {
    switch (role) {
      case Role.nursingHome:
        return 'Пансионат';
      case Role.agency:
        return 'Патронажное агентство';
      case Role.privateCaregiver:
        return 'Частная сиделка';
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedRole == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Выберите тип организации'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      _formKey.currentState?.save();
      final phone = _phoneMask.getUnmaskedText();
      final accountType = _getAccountType(_selectedRole!);

      // Отправляем событие регистрации через BLoC
      context.read<AuthBloc>().add(
        AuthRegisterRequested(
          phone: phone,
          password: _password,
          passwordConfirmation: _passwordConfirmation,
          firstName: '', // Имя не требуется
          lastName: '', // Фамилия не требуется
          accountType: accountType,
          organizationName: null,
          referralCode: null, // Реферальный код больше не используется
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          // Навигация на страницу подтверждения SMS после регистрации
          if (state is AuthAwaitingSmsVerification) {
            context.push('/verify-code/${state.phone}');
          }

          // Навигация при успешной авторизации (после подтверждения)
          if (state is AuthAuthenticated) {
            context.go('/home');
          }

          // Показ ошибки при неудаче
          if (state is AuthFailure) {
            toastification.show(
              context: context,
              type: ToastificationType.error,
              style: ToastificationStyle.fillColored,
              title: const Text('Ошибка'),
              description: Text(state.message),
              alignment: Alignment.topCenter,
              autoCloseDuration: const Duration(seconds: 4),
              borderRadius: BorderRadius.circular(12),
              showProgressBar: true,
              icon: const Icon(Icons.error),
            );
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppConfig.primaryColor,
        body: Column(
          children: [
            const SizedBox(height: 180),
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
                    vertical: 18,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (_step == 1) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => setState(() {
                                _step = 0;
                                _selectedRole = null;
                              }),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.chevron_left,
                                    size: 24,
                                    color: AppConfig.primaryColor,
                                  ),
                                  const SizedBox(width: 1),
                                  Text(
                                    'Назад к выбору типа',
                                    style: GoogleFonts.firaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppConfig.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),
                        ],
                        Text(
                          'Регистрация',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.firaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        if (_step == 1 && _selectedRole != null) ...[
                          Text(
                            _getRoleName(_selectedRole!),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.firaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey.shade900,
                            ),
                          ),
                        ],
                        const SizedBox(height: 30),

                        if (_step == 0) ...[
                          Text(
                            'Выберите тип вашей организации',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.firaSans(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _buildRoleCard(
                            title: 'Пансионат',
                            subtitle: 'Учреждение для ухода за подопечными',
                            role: Role.nursingHome,
                          ),
                          const SizedBox(height: 12),
                          _buildRoleCard(
                            title: 'Патронажное агентство',
                            subtitle: 'Агентство по предоставлению услуг ухода',
                            role: Role.agency,
                          ),
                          const SizedBox(height: 12),
                          _buildRoleCard(
                            title: 'Частная сиделка',
                            subtitle: 'Индивидуальный специалист по уходу',
                            role: Role.privateCaregiver,
                          ),
                        ] else ...[
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Введите номер телефона',
                                  style: GoogleFonts.firaSans(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  keyboardType: TextInputType.phone,
                                  decoration: _inputDecoration(
                                    'Номер телефона',
                                  ),
                                  inputFormatters: [_phoneMask],
                                  validator: (v) =>
                                      (_phoneMask.getUnmaskedText().length !=
                                          10)
                                      ? 'Введите корректный номер телефона'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Пароль',
                                  style: GoogleFonts.firaSans(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  decoration: _inputDecoration('Пароль'),
                                  validator: (v) => (v == null || v.length < 4)
                                      ? 'Минимум 4 символа'
                                      : null,
                                  onSaved: (v) => _password = (v ?? '').trim(),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Подтверждение пароля',
                                  style: GoogleFonts.firaSans(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  obscureText: true,
                                  decoration: _inputDecoration(
                                    'Подтвердите пароль',
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Подтвердите пароль';
                                    }
                                    if (v != _passwordController.text) {
                                      return 'Пароли не совпадают';
                                    }
                                    return null;
                                  },
                                  onSaved: (v) =>
                                      _passwordConfirmation = (v ?? '').trim(),
                                ),
                                const SizedBox(height: 18),
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
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        disabledBackgroundColor: AppConfig
                                            .primaryColor
                                            .withOpacity(0.6),
                                      ),
                                      onPressed: isLoading ? null : _submit,
                                      child: isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                          : Text(
                                              'Зарегистрироваться',
                                              style: GoogleFonts.firaSans(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 14),
                                Center(
                                  child: TextButton(
                                    onPressed: () => context.push('/login'),
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text:
                                                'Если уже есть аккаунт, нажмите ',
                                            style: GoogleFonts.firaSans(
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          TextSpan(
                                            text: 'Войти',
                                            style: GoogleFonts.firaSans(
                                              decoration:
                                                  TextDecoration.underline,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required Role role,
  }) {
    final bool selected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedRole = role;
        _step = 1;
      }),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5FB3BB), Color(0xFF27858A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
          border: selected ? Border.all(color: Colors.white, width: 1.5) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.firaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.firaSans(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }
}
