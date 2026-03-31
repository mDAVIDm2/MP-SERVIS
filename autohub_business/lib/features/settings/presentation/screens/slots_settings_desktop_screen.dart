import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/repositories/organization_repository.dart';
import '../../../../shared/models/settings_models.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';

/// Десктоп: слоты и подтверждение — карточки-панели, светлая тема.
class SlotsSettingsDesktopScreen extends ConsumerWidget {
  const SlotsSettingsDesktopScreen({super.key});

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
    final slots = ref.watch(settingsRepositoryProvider).slotsSettings;
    final repo = ref.read(settingsRepositoryProvider.notifier);

    Future<void> pickStart() async {
      final t = await showTimePicker(context: context, initialTime: _parseTime(slots.workDayStart));
      if (t != null) repo.updateSlots(slots.copyWith(workDayStart: _formatTime(t)));
    }

    Future<void> pickEnd() async {
      final t = await showTimePicker(context: context, initialTime: _parseTime(slots.workDayEnd));
      if (t != null) repo.updateSlots(slots.copyWith(workDayEnd: _formatTime(t)));
    }

    return Scaffold(
      backgroundColor: AppColorsDesktop.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColorsDesktop.surface,
        foregroundColor: AppColorsDesktop.textPrimary,
        title: const Text('Слоты и подтверждение'),
      ),
      body: RefreshIndicator(
        color: AppColorsDesktop.primary,
        onRefresh: () async {
          final orgId = ref.read(authProvider).user?.organizationId;
          await ref.read(settingsRepositoryProvider.notifier).load(orgId);
        },
        child: ListView(
          padding: const EdgeInsets.all(DesktopDesignSystem.pagePadding),
          children: [
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 720;
                final timeCard = _TimeRangeCard(
                  start: slots.workDayStart,
                  end: slots.workDayEnd,
                  onPickStart: () => pickStart(),
                  onPickEnd: () => pickEnd(),
                );
                if (!wide) return timeCard;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: timeCard),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: _InfoAside(
                        text:
                            'Ячейки расписания строятся от начала до конца дня с шагом выбранного слота. Последняя ячейка — не позже чем за 30 минут до конца рабочего дня.',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _OptionCard(
              title: 'Длительность одного слота записи',
              subtitle: 'Шаг сетки в календаре мастеров и онлайн-записи.',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: slotDurations.map((min) {
                  final isSelected = slots.slotDurationMinutes == min;
                  return _ChoicePill(
                    label: min < 60 ? '$min мин' : '${min ~/ 60} ч',
                    selected: isSelected,
                    onTap: () => repo.updateSlots(slots.copyWith(slotDurationMinutes: min)),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            _OptionCard(
              title: 'Таймаут подтверждения записи',
              subtitle: 'Если клиент не подтвердит заявку за это время, слот снова станет свободным.',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: timeoutMinutes.map((min) {
                  final isSelected = slots.confirmationTimeoutMinutes == min;
                  final label = min < 60 ? '$min мин' : '${min ~/ 60} ч';
                  return _ChoicePill(
                    label: label,
                    selected: isSelected,
                    onTap: () => repo.updateSlots(slots.copyWith(confirmationTimeoutMinutes: min)),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, _) {
                final org = ref.watch(organizationProvider).valueOrNull;
                final orgId = ref.watch(authProvider).user?.organizationId;
                if (org == null || orgId == null || orgId.isEmpty) return const SizedBox.shrink();
                return _OptionCard(
                  title: 'Режим расписания',
                  subtitle:
                      '«По постам» — закрепление заказов за именованным постом в расписании. Нужны посты в блоке ниже.',
                  child: SegmentedButton<String>(
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
                          SnackBar(content: Text(err.message), backgroundColor: AppColorsDesktop.error),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              mode == 'bay_based'
                                  ? 'Включён режим по постам'
                                  : 'Включён режим по мастерам',
                            ),
                            backgroundColor: AppColorsDesktop.success,
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _OptionCard(
              title: 'Посты и боксы',
              subtitle:
                  'Именованные посты для мойки, шиномонтажа и т.п. Клиент не выбирает пост — система назначает свободный. В расписании можно переключить вид «по мастерам» / «по постам».',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (slots.bays.isEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Число постов без имён: ${slots.bayCount}'),
                      subtitle: const Text('Пока список постов пуст, используется только это число'),
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      title: Text(b.name, style: DesktopDesignSystem.body),
                      subtitle: Text(b.id, style: DesktopDesignSystem.meta.copyWith(fontFamily: 'monospace')),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: AppColorsDesktop.error),
                        onPressed: () {
                          final next = List<ServiceBay>.from(slots.bays)..removeWhere((x) => x.id == b.id);
                          repo.updateSlots(slots.copyWith(bays: next));
                        },
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.add_circle_outline_rounded, color: AppColorsDesktop.primary),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoAside extends StatelessWidget {
  const _InfoAside({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesktopDesignSystem.cardPaddingLarge),
      decoration: BoxDecoration(
        color: AppColorsDesktop.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
        border: Border.all(color: AppColorsDesktop.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColorsDesktop.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: DesktopDesignSystem.bodySecondary.copyWith(height: 1.45))),
        ],
      ),
    );
  }
}

class _TimeRangeCard extends StatelessWidget {
  const _TimeRangeCard({
    required this.start,
    required this.end,
    required this.onPickStart,
    required this.onPickEnd,
  });
  final String start;
  final String end;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesktopDesignSystem.cardPaddingLarge),
      decoration: BoxDecoration(
        color: AppColorsDesktop.surface,
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCardLarge),
        border: Border.all(color: AppColorsDesktop.borderLight),
        boxShadow: DesktopDesignSystem.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Рабочий день', style: DesktopDesignSystem.sectionTitle),
          const SizedBox(height: 6),
          Text(
            'Начало и конец дня задаются вручную.',
            style: DesktopDesignSystem.bodySecondary,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _TimeTile(label: 'Начало', value: start, onTap: onPickStart),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeTile(label: 'Конец', value: end, onTap: onPickEnd),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColorsDesktop.nestedBg.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusContainer),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusContainer),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusContainer),
            border: Border.all(color: AppColorsDesktop.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: DesktopDesignSystem.label),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColorsDesktop.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text('Изменить', style: DesktopDesignSystem.meta.copyWith(color: AppColorsDesktop.primary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DesktopDesignSystem.cardPaddingLarge),
      decoration: BoxDecoration(
        color: AppColorsDesktop.surface,
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCardLarge),
        border: Border.all(color: AppColorsDesktop.borderLight),
        boxShadow: DesktopDesignSystem.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DesktopDesignSystem.sectionTitle),
          const SizedBox(height: 6),
          Text(subtitle, style: DesktopDesignSystem.bodySecondary.copyWith(height: 1.4)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColorsDesktop.primary.withValues(alpha: 0.12) : AppColorsDesktop.nestedBg.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusBadge),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusBadge),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusBadge),
            border: Border.all(
              color: selected ? AppColorsDesktop.primary : AppColorsDesktop.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: DesktopDesignSystem.body.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? AppColorsDesktop.primary : AppColorsDesktop.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
