import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_config.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';

class VerifyCodePage extends StatefulWidget {
  final String phone;
  const VerifyCodePage({super.key, required this.phone});

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  final _formKey = GlobalKey<FormState>();
  String _code = '';

  InputDecoration _inputDecoration(String hint) => InputDecoration(
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

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();
      // Отправляем событие проверки кода
      context.read<AuthBloc>().add(
        AuthVerifyPhoneRequested(phone: widget.phone, code: _code),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // Навигация при успешной верификации
        if (state is AuthAuthenticated) {
          // Если пользователь имеет роль manager (пансионат), перенаправляем на заполнение профиля
          if (state.user.hasRole('manager')) {
            context.go('/fill-organization-profile');
          } else {
            context.go('/profile');
          }
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
            const SizedBox(height: 140),
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
                    horizontal: 24.0,
                    vertical: 22,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Код подтверждения\nвыслан на номер:',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.firaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.phone,
                          style: GoogleFonts.firaSans(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Введите код из письма',
                                style: GoogleFonts.firaSans(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                decoration: _inputDecoration('Код'),
                                keyboardType: TextInputType.number,
                                validator: (v) =>
                                    (v == null || v.trim().length < 4)
                                    ? 'Введите корректный код'
                                    : null,
                                onSaved: (v) => _code = v?.trim() ?? '',
                              ),
                              const SizedBox(height: 20),
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
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : Text(
                                            'Готово',
                                            style: GoogleFonts.firaSans(
                                              fontSize: 16,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
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
}
