import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/repositories/staff_repository.dart';
import '../../../../shared/models/staff_model.dart';

class StaffDetailScreen extends ConsumerStatefulWidget {
  final StaffEntry entry;

  const StaffDetailScreen({super.key, required this.entry});

  @override
  ConsumerState<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends ConsumerState<StaffDetailScreen> {
  late TextEditingController _nameController;
  late StaffRole _role;
  late Set<String> _skills;
  late List<MasterScheduleSlot> _schedule;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.entry.name);
    _role = widget.entry.role;
    _skills = Set.from(widget.entry.skills);
    final fromEntry = widget.entry.schedule.isEmpty
        ? <MasterScheduleSlot>[]
        : widget.entry.schedule.map((s) => MasterScheduleSlot(dayOfWeek: s.dayOfWeek, startTime: s.startTime, endTime: s.endTime, isWorkingDay: s.isWorkingDay)).toList();
    _schedule = List.generate(7, (i) {
      final existing = fromEntry.where((s) => s.dayOfWeek == i).firstOrNull;
      return existing ?? MasterScheduleSlot(dayOfWeek: i, isWorkingDay: i >= 1 && i <= 5);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = ref.watch(staffRepositoryProvider).where((e) => e.id == widget.entry.id).firstOrNull ?? widget.entry;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(entry.name),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Сохранить'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Имя',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Роль',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<StaffRole>(
            segments: const [
              ButtonSegment(value: StaffRole.master, label: Text('Мастер')),
              ButtonSegment(value: StaffRole.admin, label: Text('Админ')),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
          ),
          if (_role == StaffRole.master) ...[
            const SizedBox(height: 24),
            const Text(
              'Навыки',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kSkillIds.map((skillId) {
                final selected = _skills.contains(skillId);
                return FilterChip(
                  label: Text(skillLabel(skillId)),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) _skills.add(skillId); else _skills.remove(skillId);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text(
              'График работы',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            // Неделя с понедельника: Пн, Вт, Ср, Чт, Пт, Сб, Вс (dayOfWeek 1..6, 0)
            ...([1, 2, 3, 4, 5, 6, 0].map((dayIndex) {
              const dayNames = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
              final slot = _schedule[dayIndex];
              final dayLabel = dayNames[dayIndex];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 36,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(dayLabel, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ),
                    ),
                    Checkbox(
                      value: slot.isWorkingDay,
                      onChanged: (v) {
                        setState(() {
                          _schedule[dayIndex] = MasterScheduleSlot(dayOfWeek: dayIndex, startTime: slot.startTime, endTime: slot.endTime, isWorkingDay: v ?? false);
                        });
                      },
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: ValueKey('start_$dayIndex'),
                              initialValue: slot.startTime,
                              decoration: const InputDecoration(
                                labelText: 'С',
                                isDense: true,
                                hintText: '09:00',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              onChanged: (t) {
                                setState(() {
                                  _schedule[dayIndex] = MasterScheduleSlot(dayOfWeek: dayIndex, startTime: t.trim().isEmpty ? '09:00' : t, endTime: slot.endTime, isWorkingDay: slot.isWorkingDay);
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              key: ValueKey('end_$dayIndex'),
                              initialValue: slot.endTime,
                              decoration: const InputDecoration(
                                labelText: 'По',
                                isDense: true,
                                hintText: '18:00',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              onChanged: (t) {
                                setState(() {
                                  _schedule[dayIndex] = MasterScheduleSlot(dayOfWeek: dayIndex, startTime: slot.startTime, endTime: t.trim().isEmpty ? '18:00' : t, isWorkingDay: slot.isWorkingDay);
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            })),
          ],
          if (entry.phone != null) ...[
            const SizedBox(height: 24),
            const Text(
              'Телефон',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    entry.phone!,
                    style: const TextStyle(fontSize: 16, color: AppColors.primary),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.phone_rounded, color: AppColors.primary),
                  onPressed: () {
                    final uri = Uri(scheme: 'tel', path: entry.phone!.replaceAll(RegExp(r'[^\d+]'), ''));
                    launchUrl(uri);
                  },
                ),
              ],
            ),
          ],
          if (entry.email != null) ...[
            const SizedBox(height: 8),
            const Text(
              'Email',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            SelectableText(
              entry.email!,
              style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
            ),
          ],
          const SizedBox(height: 32),
          if (entry.isActive)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              onPressed: () => _confirmDeactivate(context),
              child: const Text('Деактивировать'),
            )
          else
            OutlinedButton(
              onPressed: () async {
                final result = await ref.read(staffRepositoryProvider.notifier).activate(entry.id);
                if (!context.mounted) return;
                result.when(
                  success: (_) => Navigator.pop(context),
                  failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
                  ),
                );
              },
              child: const Text('Активировать'),
            ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите имя'), backgroundColor: AppColors.cardBg),
      );
      return;
    }
    if (_role == StaffRole.master) {
      final hasWorkingDay = _schedule.any((s) => s.isWorkingDay);
      if (!hasWorkingDay) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('У мастера должен быть указан график работы: выберите хотя бы один рабочий день'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }
    final result = await ref.read(staffRepositoryProvider.notifier).update(
          widget.entry.copyWith(
            name: name,
            role: _role,
            skills: _skills.toList(),
            schedule: _schedule,
          ),
        );
    if (!context.mounted) return;
    result.when(
      success: (_) => Navigator.pop(context),
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      ),
    );
  }

  void _confirmDeactivate(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Деактивировать?'),
        content: Text(
          '${widget.entry.name} не будет отображаться в списке и его нельзя будет назначить на новые заказы.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              final result = await ref.read(staffRepositoryProvider.notifier).deactivate(widget.entry.id);
              if (!context.mounted) return;
              result.when(
                success: (_) {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                failure: (e) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
                  );
                },
              );
            },
            child: const Text('Деактивировать'),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
