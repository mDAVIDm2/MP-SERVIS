import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/staff_repository.dart';
import '../../../../shared/models/staff_model.dart';
import '../../../../shared/models/staff_invitation_model.dart';
import 'invite_staff_screen.dart';
import 'staff_detail_screen.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffRepositoryProvider);
    final authUser = ref.watch(authProvider).user;
    final active = staff.where((e) => e.isActive).toList();
    final inactive = staff.where((e) => !e.isActive).toList();
    final canAddSelfAsMaster = authUser != null &&
        (authUser.role.canSeeStaff) &&
        staff.every((e) => e.userId != authUser.id);
    final pendingInvites = ref.watch(_pendingStaffInvitationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Персонал'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final orgId = ref.read(authProvider).user?.organizationId;
          await ref.read(staffRepositoryProvider.notifier).load(orgId);
          ref.invalidate(_pendingStaffInvitationsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
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
                  ...items.map((e) => _PendingInvitationTile(item: e)),
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
            ...inactive.map((e) => _StaffTile(entry: e, currentUserId: authUser?.id)),
            const SizedBox(height: 24),
          ],
          const Text(
            'Сотрудники',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ...active.map((e) => _StaffTile(entry: e, currentUserId: authUser?.id)),
        ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InviteStaffScreen()),
        ).then((_) => ref.invalidate(_pendingStaffInvitationsProvider)),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add_rounded),
      ),
    );
  }
}

final _pendingStaffInvitationsProvider = FutureProvider<List<StaffInvitation>>((ref) async {
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

class _StaffTile extends StatelessWidget {
  final StaffEntry entry;
  final String? currentUserId;

  const _StaffTile({required this.entry, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final isYou = entry.userId != null && entry.userId == currentUserId;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.3),
          child: Text(
            entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                entry.name,
                style: TextStyle(
                  color: entry.isActive ? null : AppColors.textTertiary,
                ),
              ),
            ),
            if (isYou)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Вы', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
          ],
        ),
        subtitle: Text(
          [
            entry.roleLabel,
            if (entry.phone != null) entry.phone,
            if (entry.email != null) entry.email,
          ].join(' • '),
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StaffDetailScreen(entry: entry),
          ),
        ),
      ),
    );
  }
}

class _PendingInvitationTile extends ConsumerWidget {
  const _PendingInvitationTile({required this.item});

  final StaffInvitation item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.cardBg,
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
        trailing: TextButton(
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
            ref.invalidate(_pendingStaffInvitationsProvider);
          },
          child: const Text('Отменить'),
        ),
      ),
    );
  }
}
