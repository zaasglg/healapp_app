/// Вкладка клиента (подопечного)
///
/// Отображает информацию о подопечном,
/// управление доступом и настройки.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../bloc/diary/diary_bloc.dart';
import '../../../bloc/diary/diary_state.dart';
import '../../../config/app_config.dart';
import '../widgets/access/access.dart';

/// Вкладка информации о клиенте
class ClientTab extends StatelessWidget {
  /// ID дневника
  final int diaryId;

  /// Является ли владельцем
  final bool isOwner;

  /// Callback при редактировании
  final VoidCallback? onEdit;

  const ClientTab({
    super.key,
    required this.diaryId,
    this.isOwner = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiaryBloc, DiaryState>(
      builder: (context, state) {
        if (state is DiaryLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is DiaryLoaded) {
          return _buildContent(context, state);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildContent(BuildContext context, DiaryLoaded state) {
    final diary = state.diary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Карточка клиента
          _buildClientCard(diary),

          const SizedBox(height: 24),

          // Информация о диагнозе
          _buildInfoSection(
            title: 'Диагноз',
            content: diary.patient?.diagnoses?.isNotEmpty == true
                ? diary.patient!.diagnoses!.join(', ')
                : 'Не указан',
            icon: Icons.medical_information_outlined,
          ),

          const SizedBox(height: 16),

          // Мобильность
          _buildInfoSection(
            title: 'Мобильность',
            content: diary.patient?.mobilityLabel ?? 'Не указана',
            icon: Icons.accessibility_outlined,
          ),

          const SizedBox(height: 24),

          // Управление доступом (только для владельца)
          if (isOwner) ...[_buildAccessSection(context, state)],

          const SizedBox(height: 24),

          // Кнопка редактирования
          if (isOwner && onEdit != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Редактировать'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppConfig.primaryColor),
                  foregroundColor: AppConfig.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClientCard(dynamic diary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConfig.primaryColor.withOpacity(0.1),
            AppConfig.primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppConfig.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // Аватар
          CircleAvatar(
            radius: 36,
            backgroundColor: AppConfig.primaryColor.withOpacity(0.2),
            backgroundImage: diary.avatarUrl != null
                ? NetworkImage(diary.avatarUrl!)
                : null,
            child: diary.avatarUrl == null
                ? Text(
                    diary.name?.isNotEmpty == true
                        ? diary.name![0].toUpperCase()
                        : '?',
                    style: GoogleFonts.firaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppConfig.primaryColor,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),

          // Информация
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  diary.name ?? 'Без имени',
                  style: GoogleFonts.firaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                  ),
                ),
                if (diary.birthDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _calculateAge(diary.birthDate!),
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                if (diary.gender != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    diary.gender == 'male' ? 'Мужской' : 'Женский',
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppConfig.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.firaSans(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessSection(BuildContext context, DiaryLoaded state) {
    // TODO: Загрузить список сотрудников с доступом через отдельный запрос
    final List<AccessEmployeeData> accessData = [];

    return AccessManagementSection(
      employees: accessData,
      isOwner: isOwner,
      onAddEmployee: () => _showAddEmployeeModal(context),
      onRemoveEmployee: (id) => _removeEmployee(context, id),
    );
  }

  void _showAddEmployeeModal(BuildContext context) {
    // TODO: Показать модальное окно выбора сотрудника
  }

  void _removeEmployee(BuildContext context, int employeeId) {
    // TODO: Удалить сотрудника
  }

  String _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }

    final years = age;
    String suffix;
    if (years % 10 == 1 && years % 100 != 11) {
      suffix = 'год';
    } else if ([2, 3, 4].contains(years % 10) &&
        ![12, 13, 14].contains(years % 100)) {
      suffix = 'года';
    } else {
      suffix = 'лет';
    }

    return '$years $suffix';
  }
}
