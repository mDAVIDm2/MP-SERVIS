import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/staff_repository.dart';
import '../../../../shared/models/staff_model.dart';
import '../../../../shared/models/staff_invitation_model.dart';
import 'invite_staff_screen.dart';
import 'staff_detail_screen.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key, this.embeddedInOrganizationCard = false});

  /// Внутри карточки организации на профиле — без AppBar и с плавающей кнопкой внизу.
  final bool embeddedInOrganizationCard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authProvider).user;
    if (authUser != null && !authUser.role.canInviteStaff) {
      final body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Раздел «Персонал» доступен только владельцу, администратору или самозанятому.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.4, color: AppColors.textSecondary),
          ),
        ),
      );
      if (embeddedInOrganizationCard) return body;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Персонал')),
        body: body,
      );
    }
    final staff = ref.watch(staffRepositoryProvider);
    final active = staff.where((e) => e.isActive).toList();
    final inactive = staff.where((e) => !e.isActive).toList();
    final canAddSelfAsMaster = authUser != null &&
        (authUser.role.canSeeStaff) &&
        staff.every((e) => e.userId != authUser.id);
    final canInvite = authUser?.role.canInviteStaff ?? false;
    final pendingInvites = ref.watch(pendingOrganizationStaffInvitationsProvider);

    final listBody = RefreshIndicator(
      onRefresh: () async {
        final orgId = ref.read(authProvider).user?.organizationId;
        await ref.read(staffRepositoryProvider.notifier).load(orgId);
        ref.invalidate(pendingOrganizationStaffInvitationsProvider);
      },
      child: ListView(
          padding: EdgeInsets.fromLTRB(16, embeddedInOrganizationCard ? 8 : 16, 16, embeddedInOrganizationCard ? 72 : 16),
          children: [
          if (canAddSelfAsMaster) ...[
            _AddMeAsMasterCard(
              onTap: () => _addMeAsMasterAndOpenSchedule(context, ref),
            ),
            const SizedBox(height: 20),
          ],
          pendingInvites.when(
            data: (items) {
              if (items.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ожидают подтверждения',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...items.map((e) => _PendingInvitationTile(item: e, canCancel: canInvite)),
                  const SizedBox(height: 20),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: LinearProgressIndicator(minHeight: 2),
            ),
            error: (error, stackTrace) => const SizedBox.shrink(),
          ),
          if (inactive.isNotEmpty) ...[
            const Text(
              'Неактивные',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ...inactive.map((e) => _StaffMemberCard(entry: e, currentUserId: authUser?.id)),
            const SizedBox(height: 24),
          ],
          const Text(
            'Сотрудники',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          ...active.map((e) => _StaffMemberCard(entry: e, currentUserId: authUser?.id)),
        ],
      ),
    );

    if (embeddedInOrganizationCard) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: listBody),
          if (canInvite)
            Positioned(
              right: 12,
              bottom: 12,
              child: FloatingActionButton(
                heroTag: 'staff_invite_embedded',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InviteStaffScreen(desktopChrome: isDesktopPlatform),
                  ),
                ).then((_) => ref.invalidate(pendingOrganizationStaffInvitationsProvider)),
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.person_add_rounded),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Персонал'),
      ),
      body: listBody,
      floatingActionButton: canInvite
          ? FloatingActionButton(
              heroTag: 'staff_invite_main',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InviteStaffScreen(desktopChrome: isDesktopPlatform),
                ),
              ).then((_) => ref.invalidate(pendingOrganizationStaffInvitationsProvider)),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.person_add_rounded),
            )
          : null,
    );
  }
}

/// Приглашения в организацию (ожидают подтверждения) — для списка персонала.
final pendingOrganizationStaffInvitationsProvider = FutureProvider<List<StaffInvitation>>((ref) async {
  final r = await ref.read(staffRepositoryProvider.notifier).getOrganizationInvitations(
        status: StaffInvitationStatus.pending,
      );
  return r.dataOrNull ?? const [];
});

Future<void> _addMeAsMasterAndOpenSchedule(BuildContext context, WidgetRef ref) async {
  final orgId = ref.read(authProvider).user?.organizationId;
  if (orgId == null) return;
  final result = await ref.read(staffRepositoryProvider.notifier).addMeAsMaster();
  final entry = result.dataOrNull;
  if (!context.mounted) return;
  if (entry != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Добавлены как мастер. Задайте график работы и сохраните.')),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StaffDetailScreen(entry: entry),
      ),
    );
  } else {
    final msg = result.errorOrNull?.message ?? 'Не удалось добавить';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.cardBg));
  }
}

class _AddMeAsMasterCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddMeAsMasterCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primary.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.3),
                child: const Icon(Icons.person_add_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Добавить меня как мастера',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffMemberCard extends StatelessWidget {
  final StaffEntry entry;
  final String? currentUserId;

  const _StaffMemberCard({required this.entry, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final isYou = entry.userId != null && entry.userId == currentUserId;
    final contact = [
      if ((entry.phone ?? '').trim().isNotEmpty) entry.phone!.trim(),
      if ((entry.email ?? '').trim().isNotEmpty) entry.email!.trim(),
    ].join(' · ');
    final scheduleText = formatStaffScheduleSummary(entry.schedule);

    return Opacity(
      opacity: entry.isActive ? 1 : 0.72,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: AppColors.cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border.withValues(alpha: 0.88)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StaffDetailScreen(entry: entry),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.22),
                        child: Text(
                          entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.name,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: entry.isActive ? AppColors.textPrimary : AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.nestedBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    entry.roleLabel,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                if (isYou)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Вы',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                    ],
                  ),
                  if (contact.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.contact_phone_outlined, size: 17, color: AppColors.textTertiary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            contact,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.schedule_rounded, size: 17, color: AppColors.textTertiary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          scheduleText,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (entry.skills.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: entry.skills.map((id) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
                          ),
                          child: Text(
                            skillLabel(id),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingInvitationTile extends ConsumerWidget {
  const _PendingInvitationTile({required this.item, required this.canCancel});

  final StaffInvitation item;
  final bool canCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: AppColors.cardBg,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: const CircleAvatar(
          backgroundColor: AppColors.nestedBg,
          child: Icon(Icons.mark_email_unread_rounded, color: AppColors.textSecondary),
        ),
        title: Text(item.invitedName?.trim().isNotEmpty == true ? item.invitedName! : 'Приглашение'),
        subtitle: Text(
          [
            item.role.label,
            if ((item.invitedPhone ?? '').isNotEmpty) item.invitedPhone,
            if ((item.invitedEmail ?? '').isNotEmpty) item.invitedEmail,
          ].join(' • '),
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        trailing: canCancel
            ? TextButton(
                onPressed: () async {
                  final r = await ref.read(staffRepositoryProvider.notifier).cancelOrganizationInvitation(item.id);
                  if (!context.mounted) return;
                  final e = r.errorOrNull;
                  if (e != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
                    );
                    return;
                  }
                  ref.invalidate(pendingOrganizationStaffInvitationsProvider);
                },
                child: const Text('Отменить'),
              )
            : const Icon(Icons.hourglass_empty_rounded, color: AppColors.textTertiary, size: 22),
      ),
    );
  }
}
