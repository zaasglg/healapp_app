import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import '../bloc/employee/employee_bloc.dart';
import '../bloc/employee/employee_event.dart';
import '../bloc/employee/employee_state.dart';
import '../bloc/organization/organization_bloc.dart';
import '../bloc/organization/organization_event.dart';
import '../bloc/organization/organization_state.dart';
import '../repositories/employee_repository.dart';
import '../config/app_config.dart';
import '../core/network/api_client.dart';
import '../utils/app_icons.dart';
import '../utils/performance_utils.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});
  static const String routeName = '/employees';

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  String _selectedRole = 'admin';

  // Маппинг API ролей к отображаемым названиям
  final Map<String, String> _roleNames = {
    'admin': 'Администратор',
    'doctor': 'Врач',
    'caregiver': 'Сиделка',
  };

  final Map<String, String> _roleDescriptions = {
    'admin':
        'Создание дневников и карточек подопечных, управление сотрудниками, изменение и заполнение дневников',
    'doctor':
        'Создание задач, заполнение дневников, просмотр карточек подопечных',
    'caregiver': 'Выполнение задач, заполнение дневников',
  };

  @override
  void initState() {
    super.initState();
    // Загружаем данные при инициализации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeBloc>().add(const LoadEmployeesRequested());
      // Загружаем данные организации для отображения имени владельца
      context.read<OrganizationBloc>().add(const LoadOrganizationRequested());
    });
  }

  void _createInvitationLink() {
    context.read<EmployeeBloc>().add(
      CreateInvitationRequested(role: _selectedRole),
    );
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

  void _deleteInvitation(int invitationId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Удалить приглашение?',
          style: GoogleFonts.firaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Приглашение будет отозвано и ссылка станет недействительной.',
          style: GoogleFonts.firaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Отмена',
              style: GoogleFonts.firaSans(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<EmployeeBloc>().add(
                DeleteInvitationRequested(invitationId: invitationId),
              );
            },
            child: Text(
              'Удалить',
              style: GoogleFonts.firaSans(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmployeeActions(Employee employee, bool isOwner) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: BlocBuilder<OrganizationBloc, OrganizationState>(
          builder: (context, orgState) {
            final displayName = _getEmployeeDisplayName(employee, orgState);
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    displayName,
                    style: GoogleFonts.firaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isOwner && employee.role != 'owner') ...[
                  ListTile(
                    leading: const Icon(Icons.swap_horiz),
                    title: Text('Изменить роль', style: GoogleFonts.firaSans()),
                    onTap: () {
                      Navigator.pop(context);
                      _showChangeRoleDialog(employee);
                    },
                  ),
                ],
                if (employee.role != 'owner')
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: Text(
                      'Удалить из организации',
                      style: GoogleFonts.firaSans(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _confirmDeleteEmployee(employee);
                    },
                  ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showChangeRoleDialog(Employee employee) {
    String newRole = employee.role;

    showDialog(
      context: context,
      builder: (context) => BlocBuilder<OrganizationBloc, OrganizationState>(
        builder: (context, orgState) {
          final displayName = _getEmployeeDisplayName(employee, orgState);
          
          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Изменить роль',
                style: GoogleFonts.firaSans(fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Выберите новую роль для $displayName',
                    style: GoogleFonts.firaSans(),
                  ),
                  const SizedBox(height: 16),
                  for (final role in ['admin', 'doctor', 'caregiver'])
                    RadioListTile<String>(
                      title: Text(
                        _roleNames[role] ?? role,
                        style: GoogleFonts.firaSans(),
                      ),
                      value: role,
                      groupValue: newRole,
                      activeColor: AppConfig.primaryColor,
                      onChanged: (value) {
                        setDialogState(() {
                          newRole = value!;
                        });
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Отмена',
                    style: GoogleFonts.firaSans(color: Colors.grey),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (newRole != employee.role) {
                      context.read<EmployeeBloc>().add(
                        UpdateEmployeeRoleRequested(
                          employeeId: employee.id,
                          newRole: newRole,
                        ),
                      );
                    }
                  },
                  child: Text(
                    'Сохранить',
                    style: GoogleFonts.firaSans(color: AppConfig.primaryColor),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteEmployee(Employee employee) {
    showDialog(
      context: context,
      builder: (context) => BlocBuilder<OrganizationBloc, OrganizationState>(
        builder: (context, orgState) {
          final displayName = _getEmployeeDisplayName(employee, orgState);
          
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Удалить сотрудника?',
              style: GoogleFonts.firaSans(fontWeight: FontWeight.w700),
            ),
            content: Text(
              'Сотрудник $displayName потеряет доступ к организации. Его аккаунт сохранится.',
              style: GoogleFonts.firaSans(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Отмена',
                  style: GoogleFonts.firaSans(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<EmployeeBloc>().add(
                    DeleteEmployeeRequested(employeeId: employee.id),
                  );
                },
                child: Text(
                  'Удалить',
                  style: GoogleFonts.firaSans(color: Colors.red),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormatterCache.formatDateTime(date);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EmployeeBloc, EmployeeState>(
      listener: (context, state) {
        if (state is InvitationCreated) {
          // Копируем ссылку в буфер обмена
          Clipboard.setData(ClipboardData(text: state.inviteUrl));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ссылка создана и скопирована в буфер обмена',
                style: GoogleFonts.firaSans(),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          // Перезагружаем данные
          context.read<EmployeeBloc>().add(const LoadEmployeesRequested());
        } else if (state is InvitationDeleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Приглашение удалено',
                style: GoogleFonts.firaSans(),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          // Перезагружаем данные
          context.read<EmployeeBloc>().add(const LoadEmployeesRequested());
        } else if (state is EmployeeRoleUpdated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Роль сотрудника изменена',
                style: GoogleFonts.firaSans(),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          // Перезагружаем данные
          context.read<EmployeeBloc>().add(const LoadEmployeesRequested());
        } else if (state is EmployeeDeleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Сотрудник удалён из организации',
                style: GoogleFonts.firaSans(),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          // Перезагружаем данные
          context.read<EmployeeBloc>().add(const LoadEmployeesRequested());
        } else if (state is EmployeeFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message, style: GoogleFonts.firaSans()),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          // Возвращаемся к загруженному состоянию
          final bloc = context.read<EmployeeBloc>();
          final cachedData = bloc.getCachedData();
          if (cachedData != null) {
            context.read<EmployeeBloc>().add(const LoadEmployeesRequested());
          }
        }
      },
      builder: (context, state) {
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
          ),
          body: SafeArea(
            child: RefreshIndicator(
              color: AppConfig.primaryColor,
              onRefresh: () async {
                context.read<EmployeeBloc>().add(
                  const LoadEmployeesRequested(),
                );
                // Ждем изменения состояния
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Block 1: Invite specialist
                    _buildInviteBlock(state),
                    const SizedBox(height: 16),

                    // Block 2: Active invitations
                    _buildInvitationsBlock(state),
                    const SizedBox(height: 16),

                    // Block 3: Employees
                    _buildEmployeesBlock(state),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInviteBlock(EmployeeState state) {
    final isLoading = state is EmployeeLoading;

    return Container(
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
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                ),
                items: _roleNames.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value, style: GoogleFonts.firaSans()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Права ${_roleNames[_selectedRole]?.toLowerCase()}:',
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
                  onPressed: isLoading ? null : _createInvitationLink,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
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
    );
  }

  Widget _buildInvitationsBlock(EmployeeState state) {
    List<Invitation> invitations = [];
    bool isLoading = state is EmployeeLoading || state is EmployeeInitial;

    if (state is EmployeeLoaded) {
      invitations = state.invitations
          .where((i) => i.status == 'pending')
          .toList();
    }

    return Container(
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
          if (isLoading)
            _buildShimmerInvitations()
          else if (invitations.isEmpty)
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
            ...invitations.map(
              (invitation) => _buildInvitationCard(invitation),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmerInvitations() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationCard(Invitation invitation) {
    // Формируем ссылку для приглашения (если inviteUrl пустой, создаем из токена)
    final String inviteLink =
        invitation.inviteUrl ??
        'https://api.sistemizdorovya.ru/invite/${invitation.token}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок с ролью и статусом
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getRoleColor(invitation.role).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    invitation.roleDisplayName,
                    style: GoogleFonts.firaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getRoleColor(invitation.role),
                    ),
                  ),
                ),
                if (invitation.isExpired) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Истекло',
                      style: GoogleFonts.firaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // Кнопка удаления
                InkWell(
                  onTap: () => _deleteInvitation(invitation.id),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Даты
            Text(
              'Создано: ${_formatDate(invitation.createdAt)}',
              style: GoogleFonts.firaSans(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Истекает: ${_formatDate(invitation.expiresAt)}',
              style: GoogleFonts.firaSans(
                fontSize: 12,
                color: invitation.isExpired ? Colors.red : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),

            // Ссылка приглашения
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ссылка для приглашения:',
                    style: GoogleFonts.firaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    inviteLink,
                    style: GoogleFonts.firaSans(
                      fontSize: 11,
                      color: AppConfig.primaryColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Кнопка скопировать
            if (!invitation.isExpired)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => _copyLink(inviteLink),
                  icon: const Icon(Icons.copy, size: 18, color: Colors.white),
                  label: Text(
                    'Скопировать ссылку',
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeesBlock(EmployeeState state) {
    List<Employee> employees = [];
    bool isLoading = state is EmployeeLoading || state is EmployeeInitial;

    if (state is EmployeeLoaded) {
      employees = state.employees;
    }

    // Проверяем, является ли текущий пользователь владельцем
    final bool isOwner = employees.any((e) => e.role == 'owner');

    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Сотрудники',
                style: GoogleFonts.firaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade900,
                ),
              ),
              if (!isLoading)
                Text(
                  '${employees.length}',
                  style: GoogleFonts.firaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            _buildShimmerEmployees()
          else if (employees.isEmpty)
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
            )
          else
            ...employees.map(
              (employee) => _buildEmployeeCard(employee, isOwner),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmerEmployees() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(Employee employee, bool isOwner) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showEmployeeActions(employee, isOwner),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: BlocBuilder<OrganizationBloc, OrganizationState>(
            builder: (context, orgState) {
              final displayName = _getEmployeeDisplayName(employee, orgState);
              
              return Row(
                children: [
                  _buildEmployeeAvatar(employee, orgState),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: GoogleFonts.firaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getRoleColor(
                                  employee.role,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                employee.roleDisplayName,
                                style: GoogleFonts.firaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _getRoleColor(employee.role),
                                ),
                              ),
                            ),
                            if (employee.phone != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                _formatPhone(employee.phone!),
                                style: GoogleFonts.firaSans(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (employee.role != 'owner')
                    Icon(Icons.more_vert, color: Colors.grey.shade400),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'owner':
        return Colors.purple;
      case 'admin':
        return Colors.blue;
      case 'doctor':
        return Colors.teal;
      case 'caregiver':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatPhone(String phone) {
    return PhoneFormatter.format(phone);
  }

  /// Виджет аватара сотрудника
  Widget _buildEmployeeAvatar(Employee employee, OrganizationState orgState) {
    // Логируем для отладки
    print('Employee avatar: ${employee.avatarUrl} for ${employee.fullName}');
    
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _getRoleColor(employee.role).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: employee.avatarUrl != null && employee.avatarUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                ApiConfig.getFullUrl(employee.avatarUrl!),
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Если ошибка загрузки фото, показываем инициалы
                  print('Error loading avatar: $error');
                  return Center(
                    child: Text(
                      _getInitialsForEmployee(employee, orgState),
                      style: GoogleFonts.firaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _getRoleColor(employee.role),
                      ),
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(_getRoleColor(employee.role)),
                    ),
                  );
                },
              ),
            )
          : Center(
              child: Text(
                _getInitialsForEmployee(employee, orgState),
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _getRoleColor(employee.role),
                ),
              ),
            ),
    );
  }

  /// Получить инициалы для сотрудника с учетом организации
  String _getInitialsForEmployee(Employee employee, OrganizationState orgState) {
    // Для владельца используем инициалы организации, если у него нет имени
    if (employee.role == 'owner' && employee.fullName == 'Без имени') {
      if (orgState is OrganizationLoaded) {
        final orgName = (orgState.organization['name'] as String?)?.trim();
        if (orgName != null && orgName.isNotEmpty) {
          // Берем первые буквы слов из названия организации
          final words = orgName.split(' ');
          if (words.length >= 2) {
            return '${words[0][0].toUpperCase()}${words[1][0].toUpperCase()}';
          } else if (words.isNotEmpty) {
            return words[0].length >= 2 
                ? '${words[0][0].toUpperCase()}${words[0][1].toUpperCase()}'
                : words[0][0].toUpperCase();
          }
        }
      }
    }

    // Обычная логика для всех остальных
    final first = employee.firstName?.isNotEmpty == true
        ? employee.firstName![0].toUpperCase()
        : '';
    final last = employee.lastName?.isNotEmpty == true
        ? employee.lastName![0].toUpperCase()
        : '';

    if (first.isEmpty && last.isEmpty) {
      return '?';
    }
    return '$last$first';
  }

  /// Получить отображаемое имя сотрудника
  /// Для владельца без имени показываем название организации
  String _getEmployeeDisplayName(Employee employee, OrganizationState orgState) {
    // Если у сотрудника есть имя, используем его
    if (employee.fullName != 'Без имени') {
      return employee.fullName;
    }

    // Для владельца без имени показываем название организации
    if (employee.role == 'owner' && orgState is OrganizationLoaded) {
      final orgName = (orgState.organization['name'] as String?)?.trim();
      if (orgName != null && orgName.isNotEmpty) {
        return orgName;
      }
    }

    return employee.fullName;
  }
}
