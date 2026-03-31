import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/repositories/organization_repository.dart';
import '../../../../shared/models/settings_models.dart';
import 'slots_settings_desktop_screen.dart';

class SlotsSettingsScreen extends ConsumerWidget {
  const SlotsSettingsScreen({super.key});

  static const List<int> slotDurations = [15, 30, 60, 90, 120];
  static const List<int> timeoutMinutes = [30, 60, 120, 240];

  static TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    final h = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 9) : 9;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  static String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isDesktopPlatform) {
      return const SlotsSettingsDesktopScreen();
    }
    final slots = ref.watch(settingsRepositoryProvider).slotsSettings;
    final repo = ref.read(settingsRepositoryProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Слоты и подтверждение'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Рабочий день',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Начало и конец дня задаются вручную. Ячейки расписания и записи строятся по этому графику (последняя ячейка — за 30 мин до конца).',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ListTile(
                  title: const Text('Начало дня', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                  subtitle: Text(slots.workDayStart, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _parseTime(slots.workDayStart),
                    );
                    if (t != null) repo.updateSlots(slots.copyWith(workDayStart: _formatTime(t)));
                  },
                ),
              ),
              Expanded(
                child: ListTile(
                  title: const Text('Конец дня', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                  subtitle: Text(slots.workDayEnd, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _parseTime(slots.workDayEnd),
                    );
                    if (t != null) repo.updateSlots(slots.copyWith(workDayEnd: _formatTime(t)));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Длительность одного слота записи',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: slotDurations.map((min) {
              final isSelected = slots.slotDurationMinutes == min;
              return ChoiceChip(
                label: Text(min < 60 ? '$min мин' : '${min ~/ 60} ч'),
                selected: isSelected,
                onSelected: (_) {
                  repo.updateSlots(slots.copyWith(slotDurationMinutes: min));
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Таймаут подтверждения записи',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Если клиент не подтвердит заявку за это время, слот освободится.',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: timeoutMinutes.map((min) {
              final isSelected = slots.confirmationTimeoutMinutes == min;
              final label = min < 60 ? '$min мин' : '${min ~/ 60} ч';
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) {
                  repo.updateSlots(slots.copyWith(confirmationTimeoutMinutes: min));
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          Consumer(
            builder: (context, ref, _) {
              final org = ref.watch(organizationProvider).valueOrNull;
              final orgId = ref.watch(authProvider).user?.organizationId;
              if (org == null || orgId == null || orgId.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Режим расписания',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Чтобы закреплять заказы за постом в расписании, выберите «По постам» и задайте именованные посты ниже.',
                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'staff_based',
                        label: Text('По мастерам'),
                        icon: Icon(Icons.person_outline_rounded, size: 18),
                      ),
                      ButtonSegment(
                        value: 'bay_based',
                        label: Text('По постам'),
                        icon: Icon(Icons.grid_view_rounded, size: 18),
                      ),
                    ],
                    selected: <String>{org.schedulingMode == 'bay_based' ? 'bay_based' : 'staff_based'},
                    onSelectionChanged: (s) async {
                      final mode = s.first;
                      if (mode == org.schedulingMode) return;
                      final next = org.copyWith(schedulingMode: mode);
                      final r = await ref.read(organizationRepositoryProvider.notifier).update(next);
                      if (!context.mounted) return;
                      final err = r.errorOrNull;
                      if (err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(err.message), backgroundColor: AppColors.error),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              mode == 'bay_based'
                                  ? 'Режим «По постам»: можно назначать заказы на пост в расписании'
                                  : 'Режим «По мастерам»',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 28),
                ],
              );
            },
          ),
          const Text(
            'Посты и боксы',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Именованные посты для мойки, шиномонтажа и т.п. Запись с приложения клиента идёт на свободный пост автоматически.',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 8),
          if (slots.bays.isEmpty)
            ListTile(
              title: Text('Число постов (без имён): ${slots.bayCount}'),
              subtitle: const Text('Пока нет списка постов — используется только это число'),
              trailing: const Icon(Icons.edit_rounded, size: 20),
              onTap: () async {
                final ctrl = TextEditingController(text: '${slots.bayCount}');
                final v = await showDialog<int>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Количество постов'),
                    content: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '1–20'),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Отмена')),
                      FilledButton(
                        onPressed: () {
                          final n = int.tryParse(ctrl.text.trim()) ?? slots.bayCount;
                          Navigator.pop(dCtx, n.clamp(1, 20));
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
                if (v != null) repo.updateSlots(slots.copyWith(bayCount: v));
              },
            ),
          ...slots.bays.map(
            (b) => ListTile(
              title: Text(b.name),
              subtitle: Text(b.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                onPressed: () {
                  final next = List<ServiceBay>.from(slots.bays)..removeWhere((x) => x.id == b.id);
                  repo.updateSlots(slots.copyWith(bays: next));
                },
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
            title: const Text('Добавить пост'),
            onTap: () async {
              final ctrl = TextEditingController();
              final name = await showDialog<String>(
                context: context,
                builder: (dCtx) => AlertDialog(
                  title: const Text('Название поста'),
                  content: TextField(
                    controller: ctrl,
                    decoration: const InputDecoration(hintText: 'Например: Бокс 1'),
                    autofocus: true,
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Отмена')),
                    FilledButton(
                      onPressed: () => Navigator.pop(dCtx, ctrl.text.trim()),
                      child: const Text('Добавить'),
                    ),
                  ],
                ),
              );
              if (name == null || name.isEmpty) return;
              final id = 'bay_${DateTime.now().millisecondsSinceEpoch}';
              repo.updateSlots(slots.copyWith(bays: [...slots.bays, ServiceBay(id: id, name: name)]));
            },
          ),
        ],
      ),
    );
  }
}
