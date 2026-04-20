import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../core/theme/desktop_light_theme.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/staff_repository.dart';
import '../../../../shared/models/staff_model.dart';

/// Карточка сотрудника: форма редактирования. Для mobile — внутри [StaffDetailScreen], для desktop — справа в split-view.
class StaffDetailPanel extends ConsumerStatefulWidget {
  const StaffDetailPanel({
    super.key,
    required this.entry,
    this.embedded = false,
    this.manageStaff = true,
    this.onSavedEmbedded,
    this.onDeactivatedEmbedded,
  });

  final StaffEntry entry;
  final bool embedded;
  /// Редактирование карт сотрудников и прав — только владелец, админ, самозанятый.
  final bool manageStaff;
  final VoidCallback? onSavedEmbedded;
  final VoidCallback? onDeactivatedEmbedded;

  @override
  ConsumerState<StaffDetailPanel> createState() => StaffDetailPanelState();
}

class StaffDetailPanelState extends ConsumerState<StaffDetailPanel> {
  late TextEditingController _nameController;
  late StaffRole _role;
  late Set<String> _skills;
  late List<MasterScheduleSlot> _schedule;
  late bool _canSeeChats;
  late bool _canWriteChats;
  late bool _canManageOrgSettings;

  void _syncFieldsFromEntry(StaffEntry e) {
    _role = e.role;
    _skills = Set.from(e.skills);
    _canSeeChats = e.canSeeChats;
    _canWriteChats = e.canWriteChats;
    _canManageOrgSettings = e.canManageOrgSettings;
    final fromEntry = e.schedule.isEmpty
        ? <MasterScheduleSlot>[]
        : e.schedule
            .map(
              (s) => MasterScheduleSlot(
                dayOfWeek: s.dayOfWeek,
                startTime: s.startTime,
                endTime: s.endTime,
                isWorkingDay: s.isWorkingDay,
              ),
            )
            .toList();
    _schedule = List.generate(7, (i) {
      final existing = fromEntry.where((s) => s.dayOfWeek == i).firstOrNull;
      return existing ?? MasterScheduleSlot(dayOfWeek: i, isWorkingDay: i >= 1 && i <= 5);
    });
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.entry.name);
    _syncFieldsFromEntry(widget.entry);
  }

  @override
  void didUpdateWidget(StaffDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id) {
      _nameController.dispose();
      _nameController = TextEditingController(text: widget.entry.name);
      _syncFieldsFromEntry(widget.entry);
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color get _cTextSec =>
      widget.embedded ? AppColorsDesktop.textSecondary : AppColors.textSecondary;
  Color get _cTextPri =>
      widget.embedded ? AppColorsDesktop.textPrimary : AppColors.textPrimary;
  Color get _cPrimary =>
      widget.embedded ? AppColorsDesktop.primary : AppColors.primary;
  Color get _cError => widget.embedded ? AppColorsDesktop.error : AppColors.error;
  Future<void> submitSave() => _save();

  Future<void> _save() async {
    if (!widget.manageStaff) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Введите имя'),
          backgroundColor: widget.embedded ? AppColorsDesktop.surface : AppColors.cardBg,
        ),
      );
      return;
    }
    if (_role == StaffRole.master) {
      final hasWorkingDay = _schedule.any((s) => s.isWorkingDay);
      if (!hasWorkingDay) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'У мастера должен быть указан график работы: выберите хотя бы один рабочий день',
            ),
            backgroundColor: _cError,
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
            canSeeChats: _canSeeChats,
            canWriteChats: _canWriteChats,
            canManageOrgSettings: _canManageOrgSettings,
          ),
        );
    if (!mounted) return;
    result.when(
      success: (_) {
        if (widget.embedded) {
          widget.onSavedEmbedded?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Сохранено'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: widget.embedded ? AppColorsDesktop.success : null,
            ),
          );
        } else {
          Navigator.pop(context);
        }
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: _cError),
      ),
    );
  }

  void _confirmDeactivate(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final dialogChild = AlertDialog(
          title: const Text('Деактивировать?'),
          content: Text(
            '${widget.entry.name} не будет отображаться в списке и его нельзя будет назначить на новые заказы.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _cError),
              onPressed: () async {
                final result =
                    await ref.read(staffRepositoryProvider.notifier).deactivate(widget.entry.id);
                if (!context.mounted) return;
                result.when(
                  success: (_) {
                    Navigator.pop(ctx);
                    if (widget.embedded) {
                      widget.onDeactivatedEmbedded?.call();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  failure: (e) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.message), backgroundColor: _cError),
                    );
                  },
                );
              },
              child: const Text('Деактивировать'),
            ),
          ],
        );
        if (widget.embedded) {
          return themeDesktopLight(child: dialogChild);
        }
        return dialogChild;
      },
    );
  }

  List<Widget> _readOnlyStaffWidgets(StaffEntry entry) {
    String yn(bool v) => v ? 'да' : 'нет';
    return [
      Text(
        entry.name,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _cTextPri),
      ),
      SizedBox(height: widget.embedded ? 16 : 12),
      Text('Роль: ${entry.roleLabel}', style: TextStyle(fontSize: 15, color: _cTextSec)),
      SizedBox(height: widget.embedded ? 20 : 16),
      Text(
        'Доступ в приложении',
        style: TextStyle(fontSize: 14, color: _cTextSec, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 8),
      Text('Вкладка «Чаты»: ${yn(entry.canSeeChats)}', style: TextStyle(fontSize: 14, color: _cTextPri)),
      Text('Писать в чатах: ${yn(entry.canWriteChats)}', style: TextStyle(fontSize: 14, color: _cTextPri)),
      Text('Настройки организации: ${yn(entry.canManageOrgSettings)}', style: TextStyle(fontSize: 14, color: _cTextPri)),
      if (entry.role == StaffRole.master) ...[
        SizedBox(height: widget.embedded ? 20 : 16),
        Text(
          'График',
          style: TextStyle(fontSize: 14, color: _cTextSec, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Text(
          formatStaffScheduleSummary(entry.schedule),
          style: TextStyle(fontSize: 14, height: 1.4, color: _cTextPri),
        ),
        if (entry.skills.isNotEmpty) ...[
          SizedBox(height: widget.embedded ? 16 : 12),
          Text('Навыки', style: TextStyle(fontSize: 14, color: _cTextSec, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: entry.skills.map((id) {
              return Chip(
                label: Text(skillLabel(id), style: TextStyle(fontSize: 12, color: _cTextPri)),
                backgroundColor: _cPrimary.withValues(alpha: 0.08),
                side: BorderSide(color: _cPrimary.withValues(alpha: 0.2)),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              );
            }).toList(),
          ),
        ],
      ],
      if (entry.phone != null && entry.phone!.trim().isNotEmpty) ...[
        SizedBox(height: widget.embedded ? 20 : 16),
        Text('Телефон', style: TextStyle(fontSize: 12, color: _cTextSec)),
        const SizedBox(height: 4),
        SelectableText(entry.phone!, style: TextStyle(fontSize: 16, color: _cPrimary)),
      ],
      if (entry.email != null && entry.email!.trim().isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('Email', style: TextStyle(fontSize: 12, color: _cTextSec)),
        const SizedBox(height: 4),
        SelectableText(entry.email!, style: TextStyle(fontSize: 16, color: _cTextPri)),
      ],
      SizedBox(height: widget.embedded ? 28 : 24),
      Text(
        'Изменить данные сотрудника и права доступа может только владелец, администратор или самозанятый.',
        style: TextStyle(fontSize: 13, height: 1.4, color: _cTextSec),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final entry = ref.watch(staffRepositoryProvider).where((e) => e.id == widget.entry.id).firstOrNull ??
        widget.entry;
    final authUser = ref.watch(authProvider).user;
    if (!widget.manageStaff) {
      final readOnly = ListView(
        padding: EdgeInsets.all(widget.embedded ? DesktopDesignSystem.pagePadding : 16),
        children: _readOnlyStaffWidgets(entry),
      );
      if (!widget.embedded) return readOnly;
      return themeDesktopLight(
        child: ColoredBox(
          color: AppColorsDesktop.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: AppColorsDesktop.surface,
                elevation: 0,
                shadowColor: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColorsDesktop.border)),
                    boxShadow: DesktopDesignSystem.shadowCard,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColorsDesktop.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.roleLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColorsDesktop.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: readOnly),
            ],
          ),
        ),
      );
    }

    final soloScheduleHint = authUser != null &&
        authUser.role == BusinessRole.solo &&
        entry.userId != null &&
        entry.userId == authUser.id &&
        _role == StaffRole.master;

    final scrollable = ListView(
      padding: EdgeInsets.all(widget.embedded ? DesktopDesignSystem.pagePadding : 16),
      children: [
        if (soloScheduleHint) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _cPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cPrimary.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: _cPrimary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Пока вы единственный мастер, дни и часы ниже совпадают с «рабочим днём» в Настройки → Слоты (начало/конец дня). '
                    'Когда в организации появится второй мастер, ваш статус станет «Владелец», а график точки и личный график настраиваются независимо.',
                    style: TextStyle(fontSize: 13, height: 1.4, color: _cTextSec),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: widget.embedded ? 20 : 16),
        ],
        TextField(
          controller: _nameController,
          style: TextStyle(color: _cTextPri),
          decoration: InputDecoration(
            labelText: 'Имя',
            labelStyle: TextStyle(color: _cTextSec),
          ),
        ),
        SizedBox(height: widget.embedded ? 20 : 16),
        Text(
          'Роль',
          style: TextStyle(
            fontSize: 14,
            color: _cTextSec,
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
        SizedBox(height: widget.embedded ? 22 : 20),
        Text(
          'Доступ в приложении',
          style: TextStyle(fontSize: 14, color: _cTextSec, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Вкладка «Чаты»', style: TextStyle(color: _cTextPri)),
          subtitle: Text(
            'Показывать раздел чатов в меню',
            style: TextStyle(fontSize: 12, color: _cTextSec),
          ),
          value: _canSeeChats,
          onChanged: (v) => setState(() {
            _canSeeChats = v;
            if (!v) _canWriteChats = false;
          }),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Писать в чатах', style: TextStyle(color: _cTextPri)),
          subtitle: Text(
            'Отправка сообщений и вложений',
            style: TextStyle(fontSize: 12, color: _cTextSec),
          ),
          value: _canWriteChats,
          onChanged: !_canSeeChats
              ? null
              : (v) => setState(() => _canWriteChats = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Настройки организации', style: TextStyle(color: _cTextPri)),
          subtitle: Text(
            'Рабочее время, услуги, комплексы, слоты',
            style: TextStyle(fontSize: 12, color: _cTextSec),
          ),
          value: _canManageOrgSettings,
          onChanged: (v) => setState(() => _canManageOrgSettings = v),
        ),
        if (_role == StaffRole.master) ...[
          SizedBox(height: widget.embedded ? 24 : 24),
          Text(
            'Навыки',
            style: TextStyle(fontSize: 14, color: _cTextSec, fontWeight: FontWeight.w500),
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
                    if (v) {
                      _skills.add(skillId);
                    } else {
                      _skills.remove(skillId);
                    }
                  });
                },
              );
            }).toList(),
          ),
          SizedBox(height: widget.embedded ? 24 : 24),
          Text(
            'График работы',
            style: TextStyle(fontSize: 14, color: _cTextSec, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
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
                      child: Text(dayLabel, style: TextStyle(fontSize: 13, color: _cTextSec)),
                    ),
                  ),
                  Checkbox(
                    value: slot.isWorkingDay,
                    onChanged: (v) {
                      setState(() {
                        _schedule[dayIndex] = MasterScheduleSlot(
                          dayOfWeek: dayIndex,
                          startTime: slot.startTime,
                          endTime: slot.endTime,
                          isWorkingDay: v ?? false,
                        );
                      });
                    },
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('start_${widget.entry.id}_$dayIndex'),
                            initialValue: slot.startTime,
                            style: TextStyle(color: _cTextPri),
                            decoration: InputDecoration(
                              labelText: 'С',
                              isDense: true,
                              hintText: '09:00',
                              labelStyle: TextStyle(color: _cTextSec),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (t) {
                              setState(() {
                                _schedule[dayIndex] = MasterScheduleSlot(
                                  dayOfWeek: dayIndex,
                                  startTime: t.trim().isEmpty ? '09:00' : t,
                                  endTime: slot.endTime,
                                  isWorkingDay: slot.isWorkingDay,
                                );
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('end_${widget.entry.id}_$dayIndex'),
                            initialValue: slot.endTime,
                            style: TextStyle(color: _cTextPri),
                            decoration: InputDecoration(
                              labelText: 'По',
                              isDense: true,
                              hintText: '18:00',
                              labelStyle: TextStyle(color: _cTextSec),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (t) {
                              setState(() {
                                _schedule[dayIndex] = MasterScheduleSlot(
                                  dayOfWeek: dayIndex,
                                  startTime: slot.startTime,
                                  endTime: t.trim().isEmpty ? '18:00' : t,
                                  isWorkingDay: slot.isWorkingDay,
                                );
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
          SizedBox(height: widget.embedded ? 24 : 24),
          Text(
            'Телефон',
            style: TextStyle(fontSize: 12, color: _cTextSec),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  entry.phone!,
                  style: TextStyle(fontSize: 16, color: _cPrimary),
                ),
              ),
              IconButton(
                icon: Icon(Icons.phone_rounded, color: _cPrimary),
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
          Text(
            'Email',
            style: TextStyle(fontSize: 12, color: _cTextSec),
          ),
          const SizedBox(height: 4),
          SelectableText(
            entry.email!,
            style: TextStyle(fontSize: 16, color: _cTextPri),
          ),
        ],
        SizedBox(height: widget.embedded ? 28 : 32),
        if (entry.isActive)
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: _cError,
              side: BorderSide(color: _cError),
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
                success: (_) {
                  if (!widget.embedded) {
                    Navigator.pop(context);
                  } else {
                    setState(() {});
                  }
                },
                failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message), backgroundColor: _cError),
                ),
              );
            },
            child: const Text('Активировать'),
          ),
      ],
    );

    if (!widget.embedded) {
      return scrollable;
    }

    return themeDesktopLight(
      child: ColoredBox(
        color: AppColorsDesktop.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: AppColorsDesktop.surface,
              elevation: 0,
              shadowColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColorsDesktop.border)),
                  boxShadow: DesktopDesignSystem.shadowCard,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColorsDesktop.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entry.roleLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColorsDesktop.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => submitSave(),
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Сохранить'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColorsDesktop.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: scrollable),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
