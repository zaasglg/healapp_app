import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../bloc/alarm/alarm_bloc.dart';
import '../../../bloc/alarm/alarm_event.dart';
import '../../../bloc/alarm/alarm_state.dart';
import '../../../repositories/alarm_repository.dart';
import '../dialogs/alarm_dialog.dart';
import '../widgets/custom_switch.dart';

/// Таб "Будильник" для страницы дневника здоровья
class AlarmTab extends StatelessWidget {
  final int diaryId;

  const AlarmTab({super.key, required this.diaryId});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AlarmBloc, AlarmState>(
      listener: (context, state) {
        if (state is AlarmCreated) {
          context.read<AlarmBloc>().add(LoadAlarms(diaryId));
        } else if (state is AlarmUpdated) {
          context.read<AlarmBloc>().add(LoadAlarms(diaryId));
        } else if (state is AlarmDeleted) {
          context.read<AlarmBloc>().add(LoadAlarms(diaryId));
        } else if (state is AlarmError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        List<Alarm> alarms = [];
        bool isLoading = false;

        if (state is AlarmsLoaded) {
          alarms = state.alarms;
        } else if (state is AlarmLoading) {
          isLoading = true;
        } else if (state is AlarmOperationInProgress) {
          alarms = state.alarms;
        }

        return SafeArea(
          child: Stack(
            children: [
              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else
                RefreshIndicator(
                  onRefresh: () async {
                    context.read<AlarmBloc>().add(LoadAlarms(diaryId));
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  color: const Color(0xFF317798),
                  child: alarms.isEmpty
                      ? _buildEmptyState(context)
                      : _buildAlarmListWithInactive(context, alarms),
                ),
              _buildAddButton(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.alarm_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'Нет будильников',
                  style: GoogleFonts.firaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Нажмите + чтобы добавить будильник',
                  style: GoogleFonts.firaSans(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Потяните вниз для обновления',
                  style: GoogleFonts.firaSans(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlarmListWithInactive(BuildContext context, List<Alarm> alarms) {
    final now = DateTime.now();
    final today = now.weekday; // 1=понедельник, 7=воскресенье
    
    // Фильтруем будильники: активные на сегодня + все неактивные
    final todayActiveAlarms = alarms.where((alarm) => 
      alarm.isActive && alarm.daysOfWeek.contains(today)
    ).toList();
    
    final inactiveAlarms = alarms.where((alarm) => !alarm.isActive).toList();
    
    // Объединяем все будильники
    final allDisplayAlarms = [...todayActiveAlarms, ...inactiveAlarms];
    
    // Сортируем по времени (берем первое время из списка times)
    allDisplayAlarms.sort((a, b) {
      final aTime = a.times.isNotEmpty ? a.times.first : '00:00';
      final bTime = b.times.isNotEmpty ? b.times.first : '00:00';
      
      final aParts = aTime.split(':');
      final bParts = bTime.split(':');
      
      final aMinutes = (int.tryParse(aParts[0]) ?? 0) * 60 + (int.tryParse(aParts[1]) ?? 0);
      final bMinutes = (int.tryParse(bParts[0]) ?? 0) * 60 + (int.tryParse(bParts[1]) ?? 0);
      
      return aMinutes.compareTo(bMinutes);
    });
    
    // Если нет будильников вообще, показываем пустое состояние
    if (allDisplayAlarms.isEmpty) {
      return _buildAllAlarmsList(context, alarms);
    }
    
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
      itemCount: allDisplayAlarms.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _AlarmCard(alarm: allDisplayAlarms[index], diaryId: diaryId),
        );
      },
    );
  }

  Widget _buildAllAlarmsList(BuildContext context, List<Alarm> alarms) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
      itemCount: alarms.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final alarm = alarms[index];
        return _AlarmCard(alarm: alarm, diaryId: diaryId);
      },
    );
  }











  Widget _buildAddButton(BuildContext context) {
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF317798), Color(0xFF0C365A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0C365A).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.add, color: Colors.white, size: 32),
            onPressed: () {
              _showAlarmDialog(context);
            },
          ),
        ),
      ),
    );
  }

  void _showAlarmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlarmDialog(
        diaryId: diaryId,
        onSave: (alarmData) {
          context.read<AlarmBloc>().add(
            CreateAlarm(
              diaryId: alarmData.diaryId,
              name: alarmData.name,
              type: alarmData.type,
              daysOfWeek: alarmData.daysOfWeek,
              times: alarmData.times,
              dosage: alarmData.dosage,
              notes: alarmData.notes,
            ),
          );
        },
      ),
    );
  }
}

/// Карточка будильника
class _AlarmCard extends StatelessWidget {
  final Alarm alarm;
  final int diaryId;

  const _AlarmCard({required this.alarm, required this.diaryId});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('alarm_${alarm.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Удалить будильник?'),
            content: Text(
              'Вы уверены, что хотите удалить будильник "${alarm.name}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Удалить'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        context.read<AlarmBloc>().add(DeleteAlarm(alarm.id));
      },
      child: GestureDetector(
        onTap: () => _showEditDialog(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
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
                      _getNextAlarmTimeText(alarm),
                      style: GoogleFonts.firaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: alarm.isActive ? const Color(0xFF333333) : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (alarm.isActive) _buildNextAlarmInfo(alarm),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        children: [
                          TextSpan(
                            text: '${alarm.type.label}: ',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text: alarm.name,
                            style: const TextStyle(fontWeight: FontWeight.w400),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.firaSans(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        children: [
                          const TextSpan(
                            text: 'Дни недели: ',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text: alarm.daysOfWeekLabel,
                            style: const TextStyle(fontWeight: FontWeight.w400),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 28,
                width: 52,
                child: CustomSwitch(
                  value: alarm.isActive,
                  onChanged: (value) {
                    context.read<AlarmBloc>().add(ToggleAlarm(alarm.id));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Строит информацию о следующем срабатывании
  Widget _buildNextAlarmInfo(Alarm alarm) {
    final now = DateTime.now();
    final today = now.weekday;
    
    // Показываем информацию только для будильников на сегодня
    if (!alarm.daysOfWeek.contains(today)) {
      return const SizedBox.shrink();
    }
    
    final currentMinutes = now.hour * 60 + now.minute;
    final currentSeconds = now.second;
    int? nextTimeMinutes;
    
    // Находим ближайшее время сегодня
    for (final timeStr in alarm.times) {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        final timeMinutes = hour * 60 + minute;
        
        // Включаем текущую минуту, если секунды меньше 50
        // Это даёт время пользователю увидеть "через 0 мин" перед срабатыванием
        if (timeMinutes > currentMinutes || 
            (timeMinutes == currentMinutes && currentSeconds < 50)) {
          nextTimeMinutes = timeMinutes;
          break;
        }
      }
    }
    
    if (nextTimeMinutes != null) {
      final diffMinutes = nextTimeMinutes - currentMinutes;
      String timeUntil;
      
      if (diffMinutes == 0) {
        // Если будильник в эту же минуту
        timeUntil = 'сейчас';
      } else if (diffMinutes < 60) {
        timeUntil = 'через $diffMinutes мин';
      } else {
        final hours = diffMinutes ~/ 60;
        final minutes = diffMinutes % 60;
        if (minutes == 0) {
          timeUntil = 'через $hours ч';
        } else {
          timeUntil = 'через $hours ч $minutes мин';
        }
      }
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          timeUntil,
          style: GoogleFonts.firaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF317798),
          ),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  /// Получает текст следующего времени срабатывания
  String _getNextAlarmTimeText(Alarm alarm) {
    if (!alarm.isActive) {
      return alarm.times.join(', ');
    }
    
    final now = DateTime.now();
    final today = now.weekday;
    
    // Если будильник не на сегодня, показываем все времена
    if (!alarm.daysOfWeek.contains(today)) {
      return alarm.times.join(', ');
    }
    
    // Находим ближайшее время сегодня
    final currentMinutes = now.hour * 60 + now.minute;
    String? nextTime;
    
    for (final timeStr in alarm.times) {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        final timeMinutes = hour * 60 + minute;
        
        if (timeMinutes > currentMinutes) {
          nextTime = timeStr;
          break;
        }
      }
    }
    
    // Если есть ближайшее время сегодня, показываем его
    if (nextTime != null) {
      return nextTime;
    }
    
    // Иначе показываем все времена
    return alarm.times.join(', ');
  }



  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlarmDialog(
        diaryId: diaryId,
        alarm: alarm,
        onSave: (data) {},
        onUpdate: (alarmId, data) {
          context.read<AlarmBloc>().add(
            UpdateAlarm(
              alarmId: alarmId,
              name: data.name,
              type: data.type,
              daysOfWeek: data.daysOfWeek,
              times: data.times,
              dosage: data.dosage,
              notes: data.notes,
            ),
          );
        },
      ),
    );
  }
}
