import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
import '../../repositories/invitation_repository.dart';
import '../../core/network/api_exceptions.dart';

enum Role { nursingHome, agency, privateCaregiver }

class RegisterPage extends StatefulWidget {
  final String? inviteToken;

  const RegisterPage({super.key, this.inviteToken});
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
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _organizationNameController =
      TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  String _password = '';
  String _passwordConfirmation = '';
  int _step = 0; // 0 = choose role, 1 = fill details
  Role? _selectedRole;
  bool _isAgree = false;
  bool _isMarketingAgree = false;
  bool _isInviteLoading = false;
  String? _inviteError;
  bool _isDiaryInviteFlow = false;

  bool get _isInviteFlow =>
      (widget.inviteToken != null && widget.inviteToken!.isNotEmpty);

  bool _isDiaryInvite(Invitation invitation) {
    final values = <String>[
      invitation.type,
      invitation.organizationType,
      invitation.role,
    ];
    for (final raw in values) {
      final value = raw.toLowerCase();
      if (value.contains('diary') ||
          value.contains('client') ||
          value.contains('patient')) {
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    if (_isInviteFlow) {
      _loadInvitationType();
    }
  }

  Future<void> _loadInvitationType() async {
    setState(() {
      _isInviteLoading = true;
      _inviteError = null;
    });

    try {
      final invitation = await invitationRepository.getInvitation(
        widget.inviteToken!,
      );

      final isDiaryInvite = _isDiaryInvite(invitation);

      setState(() {
        _isDiaryInviteFlow = isDiaryInvite;
      });

      Role? role;
      if (invitation.organizationType == 'pansionat') {
        role = Role.nursingHome;
      } else if (invitation.organizationType == 'agency') {
        role = Role.agency;
      } else if (isDiaryInvite) {
        // Для diary invites не предустанавливаем роль - даем пользователю выбрать
        role = null;
      }

      if (role == null && !isDiaryInvite) {
        setState(() {
          _inviteError = 'Тип организации недоступен для регистрации';
          _isInviteLoading = false;
        });
        return;
      }

      setState(() {
        _selectedRole = role; // Предустанавливаем роль, но оставляем шаг 0
        _step = 0; // Остаемся на шаге выбора роли
        _isAgree = false;
        _isInviteLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _inviteError = e.message;
        _isInviteLoading = false;
      });
    } catch (_) {
      setState(() {
        _inviteError = 'Не удалось загрузить приглашение';
        _isInviteLoading = false;
      });
    }
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
    );
  }

  /// Получить account_type на основе выбранного Role
  /// Для приглашений используется другое значение для privateCaregiver
  String _getAccountType(Role role, {bool forInvite = false}) {
    switch (role) {
      case Role.nursingHome:
        return 'pansionat';
      case Role.agency:
        return 'agency';
      case Role.privateCaregiver:
        // Для приглашений API ожидает 'private_caregiver'
        // Для обычной регистрации - 'specialist'
        return forInvite ? 'private_caregiver' : 'specialist';
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

      if (_isInviteFlow) {
        // Для приглашений используем специальное значение accountType
        final accountType = _getAccountType(_selectedRole!, forInvite: true);
        // Регистрация по приглашению через AuthBloc
        context.read<AuthBloc>().add(
          AuthRegisterWithInviteRequested(
            inviteToken: widget.inviteToken!,
            phone: phone,
            password: _password,
            passwordConfirmation: _passwordConfirmation,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            accountType: accountType,
            organizationName: _organizationNameController.text.trim(),
            address: _addressController.text.trim(),
          ),
        );
        return;
      }

      // Обычная регистрация
      final accountType = _getAccountType(_selectedRole!, forInvite: false);
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
          isAgree: _isAgree,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInviteFlow && _isInviteLoading) {
      return const Scaffold(
        backgroundColor: AppConfig.primaryColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_isInviteFlow && _inviteError != null) {
      return Scaffold(
        backgroundColor: AppConfig.primaryColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.white, size: 48),
                const SizedBox(height: 12),
                Text(
                  _inviteError!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.firaSans(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final inviteToken = widget.inviteToken;
                    if (inviteToken != null && inviteToken.isNotEmpty) {
                      context.push('/login?inviteToken=$inviteToken');
                    } else {
                      context.push('/login');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppConfig.primaryColor,
                  ),
                  child: Text(
                    'Перейти к входу',
                    style: GoogleFonts.firaSans(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          // Навигация на страницу подтверждения SMS после регистрации
          if (state is AuthAwaitingSmsVerification) {
            // Передаем inviteToken как query параметр для后续 обработки
            final inviteToken = widget.inviteToken;
            if (inviteToken != null && inviteToken.isNotEmpty) {
              context.push(
                '/verify-code/${state.phone}?inviteToken=$inviteToken',
              );
            } else {
              context.push('/verify-code/${state.phone}');
            }
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
                          _isInviteFlow
                              ? 'Регистрация по приглашению'
                              : 'Регистрация',
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
                          if (!_isInviteFlow || _isDiaryInviteFlow) ...[
                            const SizedBox(height: 12),
                            _buildRoleCard(
                              title: 'Частная сиделка',
                              subtitle: 'Индивидуальный специалист по уходу',
                              role: Role.privateCaregiver,
                            ),
                          ],
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
                                const SizedBox(height: 12),

                                // Поля для организации (только для pansionat/agency по приглашению)
                                if (_isInviteFlow &&
                                    !_isDiaryInviteFlow &&
                                    _selectedRole != null &&
                                    _selectedRole != Role.privateCaregiver) ...[
                                  Text(
                                    'Название организации',
                                    style: GoogleFonts.firaSans(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _organizationNameController,
                                    decoration: _inputDecoration(
                                      'Название организации',
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? 'Введите название организации'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Адрес',
                                    style: GoogleFonts.firaSans(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _addressController,
                                    decoration: _inputDecoration('Адрес'),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? 'Введите адрес'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // Checkbox Agreement
                                Row(
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: _isAgree,
                                        activeColor: AppConfig.primaryColor,
                                        onChanged: (v) {
                                          setState(() {
                                            _isAgree = v ?? false;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text.rich(
                                        TextSpan(
                                          style: GoogleFonts.firaSans(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: 'Я согласен',
                                              style: const TextStyle(
                                                color: AppConfig.primaryColor,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                              recognizer: TapGestureRecognizer()
                                                ..onTap = () {
                                                  context.push('/agreement');
                                                },
                                            ),
                                            TextSpan(
                                              text:
                                                  ' на обработку моих персональных данных, в соответствии с ',
                                              recognizer: TapGestureRecognizer()
                                                ..onTap = () {
                                                  setState(() {
                                                    _isAgree = !_isAgree;
                                                  });
                                                },
                                            ),
                                            TextSpan(
                                              text: 'политикой',
                                              style: const TextStyle(
                                                color: AppConfig.primaryColor,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                              recognizer: TapGestureRecognizer()
                                                ..onTap = () {
                                                  context.push('/policy');
                                                },
                                            ),
                                            TextSpan(
                                              text:
                                                  ' в отношении обработки персональных данных',
                                              recognizer: TapGestureRecognizer()
                                                ..onTap = () {
                                                  setState(() {
                                                    _isAgree = !_isAgree;
                                                  });
                                                },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Checkbox Marketing Agreement
                                Row(
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: _isMarketingAgree,
                                        activeColor: AppConfig.primaryColor,
                                        onChanged: (v) {
                                          setState(() {
                                            _isMarketingAgree = v ?? false;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _isMarketingAgree =
                                                !_isMarketingAgree;
                                          });
                                        },
                                        child: Text(
                                          'Даю согласие на получению информационных и рекламных сообщений',
                                          style: GoogleFonts.firaSans(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
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
                                    onPressed: () {
                                      final inviteToken = widget.inviteToken;
                                      if (inviteToken != null &&
                                          inviteToken.isNotEmpty) {
                                        context.push(
                                          '/login?inviteToken=$inviteToken',
                                        );
                                      } else {
                                        context.push('/login');
                                      }
                                    },
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
        _isAgree = false;
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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _organizationNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
