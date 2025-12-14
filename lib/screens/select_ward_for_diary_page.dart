import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_config.dart';
import '../utils/app_icons.dart';

class SelectWardForDiaryPage extends StatefulWidget {
  const SelectWardForDiaryPage({super.key});
  static const String routeName = '/select-ward-for-diary';

  @override
  State<SelectWardForDiaryPage> createState() => _SelectWardForDiaryPageState();
}

class _SelectWardForDiaryPageState extends State<SelectWardForDiaryPage> {
  final List<Map<String, dynamic>> _wards = [
    {'name': 'Мырзахмет Нурым', 'birthDate': '13.02.2019', 'gender': 'Мужской'},
  ];

  void _selectWard(Map<String, dynamic> ward) {
    context.push('/select-indicators');
  }

  void _createNewCard() {
    context.push('/new-ward-card');
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
          'Выберите карточку подопечного',
          style: GoogleFonts.firaSans(
            color: Colors.grey.shade900,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppConfig.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Выберите карточку подопечного, для которого вы хотите создать дневник',
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          color: AppConfig.primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ward cards
                    ..._wards.map((ward) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
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
                          child: InkWell(
                            onTap: () => _selectWard(ward),
                            borderRadius: BorderRadius.circular(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ward['name'],
                                        style: GoogleFonts.firaSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey.shade900,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Дата рождения: ${ward['birthDate']}',
                                        style: GoogleFonts.firaSans(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Пол: ${ward['gender']}',
                                        style: GoogleFonts.firaSans(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Image.asset(
                                  AppIcons.chevron_right,
                                  width: 20,
                                  height: 20,
                                  fit: BoxFit.contain,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            // Bottom button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: InkWell(
                  onTap: _createNewCard,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppConfig.primaryColor,
                          AppConfig.primaryColor.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Создать новую карточку',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.firaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
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
