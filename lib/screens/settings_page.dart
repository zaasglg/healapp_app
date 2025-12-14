import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/app_config.dart';
import '../utils/app_icons.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/auth/auth_state.dart';

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

  String _organizationName = 'n4msin@mail.ru';
  String _phone = 'n4msin@mail.ru';
  String _address = '';
  String _roleType = 'Пансионат';

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

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          context.go('/login');
        } else if (state is AuthFailure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
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
                Center(
                  child: Text(
                    _roleType,
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Form
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
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
                        Center(
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  // TODO: Implement avatar selection
                                },
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  child: Center(
                                    child: SvgPicture.asset(
                                      AppIcons.profile,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              TextButton(
                                onPressed: () {
                                  // TODO: Implement avatar selection
                                },
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
                        ),

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
                          initialValue: _organizationName,
                          decoration: _inputDecoration('Название организации'),
                          onChanged: (value) => _organizationName = value,
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
                          initialValue: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDecoration('Номер телефона'),
                          inputFormatters: [_phoneMask],
                          onChanged: (value) => _phone = value,
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
                          decoration: _inputDecoration(
                            'Введите адрес места нахождения организации',
                          ),
                          maxLines: 3,
                          onChanged: (value) => _address = value,
                        ),

                        SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConfig.primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              if (_formKey.currentState?.validate() ?? false) {
                                // TODO: Implement save functionality
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Изменения сохранены'),
                                  ),
                                );
                                context.pop();
                              }
                            },
                            child: Text(
                              'Сохранить изменения',
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
      ),
    );
  }
}
