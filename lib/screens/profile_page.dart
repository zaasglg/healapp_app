import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../utils/app_icons.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/auth/auth_state.dart';
import '../core/network/api_client.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  static const String routeName = '/profile';

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    // Обновляем данные пользователя при открытии страницы
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthBloc>().add(const AuthRefreshUser());
    });
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.firaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: GoogleFonts.firaSans(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Image.asset(
              AppIcons.chevron_right,
              width: 20,
              height: 20,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }

  /// Получить имя для отображения (организация или имя сиделки)
  String _getDisplayName(Map<String, dynamic>? userData) {
    if (userData == null) return '';

    final accountType = userData['account_type'] as String?;

    // Для частной сиделки или клиента показываем имя и фамилию
    if (accountType == 'specialist' || accountType == 'client') {
      final firstName = (userData['first_name'] as String?)?.trim() ?? '';
      final lastName = (userData['last_name'] as String?)?.trim() ?? '';

      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        return '$firstName $lastName'.trim();
      }

      // Пробуем поле name
      final name = (userData['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) {
        return name;
      }

      // Если имя не заполнено, показываем телефон
      return (userData['phone'] as String?)?.trim() ?? '';
    }

    // Для организаций показываем название организации
    final organization = userData['organization'] as Map<String, dynamic>?;
    if (organization != null) {
      final name = (organization['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) return name;
    }

    return '';
  }

  /// Получить отображаемый контакт
  String _getDisplayContact(Map<String, dynamic>? userData) {
    if (userData == null) return '';

    final email = (userData['email'] as String?)?.trim();
    final phone = (userData['phone'] as String?)?.trim();

    if (email != null && email.isNotEmpty) return email;
    if (phone != null && phone.isNotEmpty) return phone;

    return '';
  }

  /// Виджет для отображения аватара
  Widget _buildAvatar(String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      // Преобразуем относительный путь в полный URL
      final fullUrl = ApiConfig.getFullUrl(avatarUrl);
      debugPrint('ProfilePage: fullUrl = $fullUrl');

      return ClipOval(
        child: Image.network(
          fullUrl,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SvgPicture.asset(
                  AppIcons.profile,
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                ),
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 56,
              height: 56,
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
                  strokeWidth: 2,
                ),
              ),
            );
          },
        ),
      );
    }

    return Container(
      width: 56,
      height: 56,
      child: Center(
        child: SvgPicture.asset(
          AppIcons.profile,
          width: 56,
          height: 56,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F7),
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
          'Профиль',
          style: GoogleFonts.firaSans(
            color: Colors.grey.shade900,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              // Получаем данные пользователя из состояния
              Map<String, dynamic>? userData;
              String? avatarUrl;
              String? accountType;
              if (state is AuthAuthenticated) {
                userData = state.user.additionalData;
                avatarUrl = state.user.avatar;
                accountType = state.user.accountType;
                // Логируем для отладки
                debugPrint('ProfilePage: avatarUrl = $avatarUrl');
                debugPrint(
                  'ProfilePage: userData avatar = ${userData?['avatar']}',
                );
              }

              final isSpecialist = accountType == 'specialist';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _buildAvatar(avatarUrl),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getDisplayName(userData),
                                    style: GoogleFonts.firaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.grey.shade900,
                                    ),
                                  ),
                                  Text(
                                    _getDisplayContact(userData),
                                    style: GoogleFonts.firaSans(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: SizedBox(
                                      height: 28,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppConfig.primaryColor,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 0,
                                          ),
                                          minimumSize: const Size(0, 28),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        onPressed: () =>
                                            context.push('/settings'),
                                        child: Text(
                                          'Настройки',
                                          style: GoogleFonts.firaSans(
                                            fontSize: 12,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Управление профилем',
                    style: GoogleFonts.firaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildMenuCard(
                            context: context,
                            title: 'Мои дневники',
                            subtitle: 'Просмотр и управление',
                            onTap: () => context.push('/diaries'),
                          ),
                          _buildMenuCard(
                            context: context,
                            title: 'Карточки подопечных',
                            subtitle: 'Просмотр и редактирование',
                            onTap: () => context.push('/wards'),
                          ),
                          // Для клиентов показываем только "Мои дневники"
                          if (accountType != 'client') ...[
                            // Показываем только для организаций
                            if (!isSpecialist)
                              _buildMenuCard(
                                context: context,
                                title: 'Сотрудники',
                                subtitle: 'Управление командой',
                                onTap: () => context.push('/employees'),
                              ),
                            _buildMenuCard(
                              context: context,
                              title: 'Клиенты',
                              subtitle: 'Список клиентов',
                              onTap: () => context.push('/clients'),
                            ),
                          ],
                          const SizedBox(height: 36),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConfig.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: () async {
                        final url = Uri.parse(
                          'https://api.whatsapp.com/send/?phone=79145391376&text&type=phone_number&app_absent=0',
                        );
                        if (await canLaunchUrl(url)) {
                          await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Не удалось открыть WhatsApp'),
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        'Связаться с поддержкой',
                        style: GoogleFonts.firaSans(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
