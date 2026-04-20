import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/staff_repository.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../shared/models/staff_model.dart';
import '../../../../shared/models/staff_invitation_model.dart';
import 'invite_staff_screen.dart';
import 'staff_detail_panel.dart';
import 'staff_screen.dart' show pendingOrganizationStaffInvitationsProvider;

/// Десктоп: вкладка «Персонал» в настройках — светлый фон, список слева, карточка сотрудника справа.
class StaffDesktopScreen extends ConsumerStatefulWidget {
  const StaffDesktopScreen({super.key});

  @override
  ConsumerState<StaffDesktopScreen> createState() => _StaffDesktopScreenState();
}

class _StaffDesktopScreenState extends ConsumerState<StaffDesktopScreen> {
  String? _selectedId;

  Future<void> _refresh() async {
    final orgId = ref.read(authProvider).user?.organizationId;
    await ref.read(staffRepositoryProvider.notifier).load(orgId);
    ref.invalidate(pendingOrganizationStaffInvitationsProvider);
  }

  Future<void> _addMeAsMaster() async {
    final result = await ref.read(staffRepositoryProvider.notifier).addMeAsMaster();
    final entry = result.dataOrNull;
    if (!mounted) return;
    if (entry != null) {
      setState(() => _selectedId = entry.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавлены как мастер. Задайте график работы и сохраните.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final msg = result.errorOrNull?.message ?? 'Не удалось добавить';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColorsDesktop.error),
      );
    }
  }

  StaffEntry? _selectedEntry(List<StaffEntry> staff) {
    if (_selectedId == null) return null;
    final m = staff.where((e) => e.id == _selectedId);
    return m.isEmpty ? null : m.first;
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).user;
    if (authUser != null && !authUser.role.canInviteStaff) {
      return ColoredBox(
        color: AppColorsDesktop.background,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Раздел «Персонал» доступен только владельцу, администратору или самозанятому.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.45, color: AppColorsDesktop.textSecondary),
            ),
          ),
        ),
      );
    }
    final staff = ref.watch(staffRepositoryProvider);
    final active = staff.where((e) => e.isActive).toList();
    final inactive = staff.where((e) => !e.isActive).toList();
    final canAddSelfAsMaster = authUser != null &&
        authUser.role.canSeeStaff &&
        staff.every((e) => e.userId != authUser.id);
    final pendingInvites = ref.watch(pendingOrganizationStaffInvitationsProvider);
    final selected = _selectedEntry(staff);

    return ColoredBox(
      color: AppColorsDesktop.background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 380,
            child: Material(
              color: AppColorsDesktop.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Персонал',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColorsDesktop.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Обновить',
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded, color: AppColorsDesktop.textSecondary),
                        ),
                        const SizedBox(width: 4),
                        if (authUser?.role.canInviteStaff ?? false)
                          FilledButton.icon(
                            onPressed: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(builder: (_) => const InviteStaffScreen(desktopChrome: true)),
                            ).then((_) {
                              ref.invalidate(pendingOrganizationStaffInvitationsProvider);
                            }),
                            icon: const Icon(Icons.person_add_rounded, size: 18),
                            label: const Text('Пригласить'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColorsDesktop.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusButton),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColorsDesktop.border),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      children: [
                        if (canAddSelfAsMaster) ...[
                          _AddMeMasterTileDesktop(onTap: _addMeAsMaster),
                          const SizedBox(height: 16),
                        ],
                        pendingInvites.when(
                          data: (items) {
                            if (items.isEmpty) return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionLabel('Ожидают подтверждения'),
                                const SizedBox(height: 8),
                                ...items.map((e) => _PendingInviteRowDesktop(item: e)),
                                const SizedBox(height: 20),
                              ],
                            );
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: LinearProgressIndicator(minHeight: 2, color: AppColorsDesktop.primary),
                          ),
                          error: (_, _) => const SizedBox.shrink(),
                        ),
                        if (inactive.isNotEmpty) ...[
                          _sectionLabel('Неактивные'),
                          const SizedBox(height: 8),
                          ...inactive.map(
                            (e) => _StaffRowDesktop(
                              entry: e,
                              selected: _selectedId == e.id,
                              currentUserId: authUser?.id,
                              onTap: () => setState(() => _selectedId = e.id),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        _sectionLabel('Сотрудники'),
                        const SizedBox(height: 8),
                        ...active.map(
                          (e) => _StaffRowDesktop(
                            entry: e,
                            selected: _selectedId == e.id,
                            currentUserId: authUser?.id,
                            onTap: () => setState(() => _selectedId = e.id),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1, color: AppColorsDesktop.border),
          Expanded(
            child: selected == null
                ? _EmptyDetailPane()
                : StaffDetailPanel(
                    key: ValueKey(selected.id),
                    entry: selected,
                    embedded: true,
                    manageStaff: authUser?.role.canInviteStaff ?? false,
                    onDeactivatedEmbedded: () => setState(() => _selectedId = null),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDetailPane extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColorsDesktop.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.badge_outlined,
              size: 56,
              color: AppColorsDesktop.textPlaceholder,
            ),
            const SizedBox(height: 16),
            Text(
              'Выберите сотрудника',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColorsDesktop.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Слева список команды — нажмите на человека,\nчтобы открыть карточку и редактировать данные.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColorsDesktop.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _sectionLabel(String text) {
  return Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColorsDesktop.textSecondary,
      letterSpacing: 0.2,
    ),
  );
}

class _AddMeMasterTileDesktop extends StatelessWidget {
  const _AddMeMasterTileDesktop({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColorsDesktop.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColorsDesktop.primary.withValues(alpha: 0.2),
                child: const Icon(Icons.person_add_rounded, color: AppColorsDesktop.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Добавить меня как мастера',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColorsDesktop.primary,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColorsDesktop.textTertiary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffRowDesktop extends StatelessWidget {
  const _StaffRowDesktop({
    required this.entry,
    required this.selected,
    required this.currentUserId,
    required this.onTap,
  });

  final StaffEntry entry;
  final bool selected;
  final String? currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isYou = entry.userId != null && entry.userId == currentUserId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColorsDesktop.primary.withValues(alpha: 0.1) : AppColorsDesktop.nestedBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusContainer),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusContainer),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusContainer),
              border: Border.all(
                color: selected ? AppColorsDesktop.primary : AppColorsDesktop.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColorsDesktop.primary.withValues(alpha: 0.2),
                  child: Text(
                    entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppColorsDesktop.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: entry.isActive
                                    ? AppColorsDesktop.textPrimary
                                    : AppColorsDesktop.textTertiary,
                              ),
                            ),
                          ),
                          if (isYou)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColorsDesktop.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Вы',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColorsDesktop.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          entry.roleLabel,
                          if (entry.phone != null) entry.phone,
                          if (entry.email != null) entry.email,
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColorsDesktop.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingInviteRowDesktop extends ConsumerWidget {
  const _PendingInviteRowDesktop({required this.item});

  final StaffInvitation item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColorsDesktop.surface,
          borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusContainer),
          border: Border.all(color: AppColorsDesktop.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.mark_email_unread_outlined, color: AppColorsDesktop.textSecondary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.invitedName?.trim().isNotEmpty == true ? item.invitedName! : 'Приглашение',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColorsDesktop.textPrimary,
                    ),
                  ),
                  Text(
                    [
                      item.role.label,
                      if ((item.invitedPhone ?? '').isNotEmpty) item.invitedPhone,
                      if ((item.invitedEmail ?? '').isNotEmpty) item.invitedEmail,
                    ].join(' · '),
                    style: const TextStyle(fontSize: 12, color: AppColorsDesktop.textSecondary),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () async {
                final r = await ref.read(staffRepositoryProvider.notifier).cancelOrganizationInvitation(item.id);
                if (!context.mounted) return;
                final e = r.errorOrNull;
                if (e != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message), backgroundColor: AppColorsDesktop.error),
                  );
                  return;
                }
                ref.invalidate(pendingOrganizationStaffInvitationsProvider);
              },
              child: const Text('Отменить'),
            ),
          ],
        ),
      ),
    );
  }
}
