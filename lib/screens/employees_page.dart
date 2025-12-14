import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../config/app_config.dart';
import '../utils/app_icons.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});
  static const String routeName = '/employees';

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  String? _selectedRole = 'Администратор';
  final List<String> _roles = ['Администратор', 'Медсестра', 'Сиделка'];
  final Map<String, String> _roleDescriptions = {
    'Администратор':
        'Создание дневников и карточек подопечных, изменение и заполнение дневников',
    'Медсестра': 'Заполнение дневников, просмотр карточек подопечных',
    'Сиделка': 'Заполнение дневников',
  };

  final List<Map<String, dynamic>> _activeInvitations = [
    {
      'role': 'Администратор',
      'created': '28.11.2025, 08:41',
      'link':
          'https://healapp.ru/register?org_token=417ac3b8-3d3b-461a-82f2-6a4e99a77b6b',
    },
  ];

  void _createInvitationLink() {
    // TODO: Implement API call to create invitation link
    setState(() {
      // Mock: Add invitation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ссылка создана и скопирована в буфер обмена'),
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  void _copyLink(String link) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ссылка скопирована'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _deleteInvitation(int index) {
    setState(() {
      _activeInvitations.removeAt(index);
    });
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
          'Сотрудники',
          style: GoogleFonts.firaSans(
            color: Colors.grey.shade900,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.grey.shade600),
            onPressed: () {
              // TODO: Implement refresh
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Block 1: Invite specialist
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Пригласить специалиста',
                      style: GoogleFonts.firaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Выберите роль',
                          style: GoogleFonts.firaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 16,
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
                          ),
                          items: _roles.map((role) {
                            return DropdownMenuItem(
                              value: role,
                              child: Text(role, style: GoogleFonts.firaSans()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedRole = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Права ${_selectedRole?.toLowerCase()}:',
                          style: GoogleFonts.firaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _roleDescriptions[_selectedRole] ?? '',
                          style: GoogleFonts.firaSans(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 20),
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
                            onPressed: _createInvitationLink,
                            child: Text(
                              'Создать пригласительную ссылку',
                              style: GoogleFonts.firaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ссылка создаётся мгновенно и автоматически копируется. Передайте её сотруднику в удобном мессенджере.',
                          style: GoogleFonts.firaSans(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Block 2: Active invitations
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Активные приглашения',
                      style: GoogleFonts.firaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_activeInvitations.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Нет активных приглашений',
                            style: GoogleFonts.firaSans(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._activeInvitations.asMap().entries.map((entry) {
                        final index = entry.key;
                        final invitation = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        invitation['role'],
                                        style: GoogleFonts.firaSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey.shade900,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Создано: ${invitation['created']}',
                                        style: GoogleFonts.firaSans(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SelectableText(
                                        invitation['link'],
                                        style: GoogleFonts.firaSans(
                                          fontSize: 11,
                                          color: AppConfig.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 130,
                                  child: Column(
                                    children: [
                                      InkWell(
                                        onTap: () =>
                                            _copyLink(invitation['link']),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                AppConfig.primaryColor,
                                                AppConfig.primaryColor
                                                    .withOpacity(0.8),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            'Скопировать',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.firaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey.shade300,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          elevation: 0,
                                          minimumSize: const Size.fromHeight(0),
                                        ),
                                        onPressed: () =>
                                            _deleteInvitation(index),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: Text(
                                            'Удалить',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.firaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Block 3: Employees
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Сотрудники',
                      style: GoogleFonts.firaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Пока нет сотрудников. Отправьте приглашение, чтобы добавить специалиста в команду.',
                          style: GoogleFonts.firaSans(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
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
    );
  }
}
