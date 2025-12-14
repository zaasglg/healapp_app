import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../config/app_config.dart';
import '../../bloc/organization/organization_bloc.dart';
import '../../bloc/organization/organization_event.dart';
import '../../bloc/organization/organization_state.dart';

class FillOrganizationProfilePage extends StatefulWidget {
  const FillOrganizationProfilePage({super.key});
  static const String routeName = '/fill-organization-profile';

  @override
  State<FillOrganizationProfilePage> createState() =>
      _FillOrganizationProfilePageState();
}

class _FillOrganizationProfilePageState
    extends State<FillOrganizationProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final MaskTextInputFormatter _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {"#": RegExp(r'\d')},
  );

  String _organizationName = '';
  String _phone = '';
  String _address = '';

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

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();
      final phone = _phoneMask.getUnmaskedText();

      context.read<OrganizationBloc>().add(
        UpdateOrganizationRequested(
          name: _organizationName,
          phone: phone,
          address: _address,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrganizationBloc, OrganizationState>(
      listener: (context, state) {
        // Навигация при успешном обновлении
        if (state is OrganizationUpdated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Профиль организации обновлён'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Задержка перед переходом на главную
          Future.delayed(const Duration(milliseconds: 500), () {
            context.go('/home');
          });
        }

        // Показ ошибки при неудаче
        if (state is OrganizationFailure) {
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
                          'Пансионат',
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
                                'Название организации',
                                style: GoogleFonts.firaSans(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                decoration: _inputDecoration(
                                  'Введите название организации',
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Укажите название организации'
                                    : null,
                                onSaved: (v) =>
                                    _organizationName = (v ?? '').trim(),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Номер телефона',
                                style: GoogleFonts.firaSans(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                keyboardType: TextInputType.phone,
                                decoration: _inputDecoration('Номер телефона'),
                                inputFormatters: [_phoneMask],
                                validator: (v) =>
                                    (_phoneMask.getUnmaskedText().length != 10)
                                    ? 'Введите корректный номер телефона'
                                    : null,
                                onSaved: (v) => _phone = (v ?? '').trim(),
                              ),
                              const SizedBox(height: 12),
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
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                decoration: _inputDecoration(
                                  'Введите адрес места нахождения организации',
                                ),
                                maxLines: 3,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Укажите адрес организации'
                                    : null,
                                onSaved: (v) => _address = (v ?? '').trim(),
                              ),
                              const SizedBox(height: 24),
                              BlocBuilder<OrganizationBloc, OrganizationState>(
                                builder: (context, state) {
                                  final isLoading =
                                      state is OrganizationLoading;

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
}
