import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/organization_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../providers/pending_invitations_count_provider.dart';
import '../widgets/user_profile_avatar.dart';
import '../widgets/invitation_count_badge.dart';
import 'incoming_invitations_screen.dart';

/// Тело экрана настроек аккаунта (мобильная тёмная или десктопная светлая оболочка).
class AccountSettingsBody extends ConsumerStatefulWidget {
  const AccountSettingsBody({super.key, required this.desktopChrome});

  final bool desktopChrome;

  @override
  ConsumerState<AccountSettingsBody> createState() => _AccountSettingsBodyState();
}

class _AccountSettingsBodyState extends ConsumerState<AccountSettingsBody> {
  bool _avatarBusy = false;
  bool _deleteBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(pendingInvitationsCountProvider);
    });
  }

  Future<void> _pickAvatar() async {
    if (_avatarBusy) return;
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
    );
    if (xFile == null || !mounted) return;
    setState(() => _avatarBusy = true);
    final bytes = await xFile.readAsBytes();
    final name = xFile.name.trim().isNotEmpty ? xFile.name : 'avatar.jpg';
    final r = await ref.read(authProvider.notifier).uploadProfileAvatarBytes(bytes, name);
    if (!mounted) return;
    setState(() => _avatarBusy = false);
    final errColor = widget.desktopChrome ? AppColorsDesktop.error : AppColors.error;
    r.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Фото профиля обновлено'), behavior: SnackBarBehavior.floating),
        );
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: errColor),
        );
      },
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final d = widget.desktopChrome;
        return AlertDialog(
          backgroundColor: d ? AppColorsDesktop.surface : null,
          title: Text(
            'Удалить аккаунт?',
            style: d ? DesktopDesignSystem.sectionTitle : null,
          ),
          content: Text(
            'Все данные профиля и доступ к организациям будут удалены без возможности восстановления.',
            style: d ? DesktopDesignSystem.bodySecondary.copyWith(height: 1.4) : null,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: d ? AppColorsDesktop.error : AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить навсегда'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleteBusy = true);
    final r = await ref.read(authProvider.notifier).deleteAccount();
    if (!mounted) return;
    setState(() => _deleteBusy = false);
    final d = widget.desktopChrome;
    final errColor = d ? AppColorsDesktop.error : AppColors.error;
    r.when(
      success: (_) {},
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: errColor),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.desktopChrome;
    final user = ref.watch(authProvider).user;
    final orgAsync = ref.watch(organizationProvider);
    final pendingAsync = ref.watch(pendingInvitationsCountProvider);
    final pending = pendingAsync.valueOrNull ?? 0;

    if (user == null) {
      return Center(
        child: Text(
          'Нет данных профиля',
          style: d ? DesktopDesignSystem.body : const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final soloNoOrg = user.role == BusinessRole.solo && user.effectiveOrganizationId == null;
    final orgDisplayName = soloNoOrg
        ? 'Не создана — откройте «Мой сервис» в настройках'
        : (orgAsync.valueOrNull?.name.trim().isNotEmpty == true
            ? orgAsync.valueOrNull!.name
            : 'Загрузка…');

    final pad = d ? DesktopDesignSystem.pagePadding : 16.0;
    final sectionStyle = d
        ? DesktopDesignSystem.label.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2)
        : TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          );
    final hintStyle = d
        ? DesktopDesignSystem.bodySecondary
        : TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.9));
    final cameraBg = d ? AppColorsDesktop.primary : AppColors.primary;
    final cameraIcon = d ? Colors.white : const Color(0xFF0D0D0D);

    final list = ListView(
      padding: EdgeInsets.fromLTRB(pad, d ? 8 : 0, pad, pad + 24),
      children: [
        if (d) ...[
          _DesktopAccountHero(
            userName: user.displayName,
            roleLabel: user.role.label,
            child: _avatarBlock(
              d: d,
              cameraBg: cameraBg,
              cameraIcon: cameraIcon,
              hintStyle: hintStyle,
            ),
          ),
          const SizedBox(height: 28),
        ] else ...[
          Center(
            child: Column(
              children: [
                _avatarBlock(
                  d: d,
                  cameraBg: cameraBg,
                  cameraIcon: cameraIcon,
                  hintStyle: hintStyle,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        Text('Контакты', style: sectionStyle),
        SizedBox(height: d ? 12 : 8),
        _ContactsCard(
          desktopChrome: d,
          user: user,
        ),
        SizedBox(height: d ? 28 : 20),
        Text('Организация', style: sectionStyle),
        SizedBox(height: d ? 12 : 8),
        _OrgTile(desktopChrome: d, orgName: orgDisplayName),
        SizedBox(height: d ? 28 : 20),
        Text('Приглашения', style: sectionStyle),
        SizedBox(height: d ? 12 : 8),
        _InvitationsTile(
          desktopChrome: d,
          pending: pending,
          onTap: () async {
            await Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => IncomingInvitationsScreen(desktopChrome: d),
              ),
            );
            if (mounted) ref.invalidate(pendingInvitationsCountProvider);
          },
        ),
        SizedBox(height: d ? 36 : 28),
        Text('Аккаунт', style: sectionStyle),
        SizedBox(height: d ? 12 : 8),
        if (d)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DesktopDesignSystem.cardPaddingLarge),
            decoration: BoxDecoration(
              color: AppColorsDesktop.surface,
              borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
              border: Border.all(color: AppColorsDesktop.border),
              boxShadow: DesktopDesignSystem.shadowCard,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Удаление аккаунта необратимо. Связанные сессии будут завершены.',
                  style: DesktopDesignSystem.bodySecondary.copyWith(height: 1.4),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _deleteBusy ? null : _confirmDeleteAccount,
                  icon: _deleteBusy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColorsDesktop.error,
                          ),
                        )
                      : const Icon(Icons.delete_forever_outlined, size: 20),
                  label: Text(_deleteBusy ? 'Удаление…' : 'Удалить аккаунт'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColorsDesktop.error,
                    side: BorderSide(color: AppColorsDesktop.error.withValues(alpha: 0.55)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          )
        else
          Card(
            color: AppColors.cardBg,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Удаление аккаунта необратимо.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _deleteBusy ? null : _confirmDeleteAccount,
                    icon: _deleteBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                          )
                        : const Icon(Icons.delete_forever_outlined, size: 20),
                    label: Text(_deleteBusy ? 'Удаление…' : 'Удалить аккаунт'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    if (d) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: list,
        ),
      );
    }
    return list;
  }

  Widget _avatarBlock({
    required bool d,
    required Color cameraBg,
    required Color cameraIcon,
    required TextStyle hintStyle,
  }) {
    return Column(
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              const UserProfileAvatar(radius: 44),
              if (_avatarBusy)
                Positioned.fill(
                  child: ClipOval(
                    child: Container(
                      color: Colors.black26,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Material(
                  color: cameraBg,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _avatarBusy ? null : _pickAvatar,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.camera_alt_outlined, color: cameraIcon, size: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text('Фото профиля', style: hintStyle),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _avatarBusy ? null : _pickAvatar,
          child: const Text('Выбрать из галереи'),
        ),
      ],
    );
  }
}

class _DesktopAccountHero extends StatelessWidget {
  const _DesktopAccountHero({
    required this.userName,
    required this.roleLabel,
    required this.child,
  });

  final String userName;
  final String roleLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesktopDesignSystem.cardPaddingLarge + 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColorsDesktop.primary.withValues(alpha: 0.07),
            AppColorsDesktop.surface,
            AppColorsDesktop.nestedBg.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCardLarge),
        border: Border.all(color: AppColorsDesktop.borderLight),
        boxShadow: DesktopDesignSystem.shadowCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          const SizedBox(width: 28),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName, style: DesktopDesignSystem.pageTitle.copyWith(fontSize: 20)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColorsDesktop.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusBadge),
                  ),
                  child: Text(
                    roleLabel,
                    style: DesktopDesignSystem.meta.copyWith(
                      color: AppColorsDesktop.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Аватар и контакты видны в приложении. Приглашения в другие организации обрабатываются ниже.',
                  style: DesktopDesignSystem.bodySecondary.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactsCard extends StatelessWidget {
  const _ContactsCard({required this.desktopChrome, required this.user});

  final bool desktopChrome;
  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final d = desktopChrome;
    if (d) {
      return Container(
        decoration: BoxDecoration(
          color: AppColorsDesktop.surface,
          borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
          border: Border.all(color: AppColorsDesktop.border),
          boxShadow: DesktopDesignSystem.shadowCard,
        ),
        child: Column(
          children: [
            _ContactRow(
              desktopChrome: true,
              icon: Icons.email_outlined,
              label: 'Электронная почта',
              value: (user.email != null && user.email!.trim().isNotEmpty) ? user.email! : '—',
              verified: user.email != null && user.email!.trim().isNotEmpty && user.emailVerified,
            ),
            Divider(height: 1, color: AppColorsDesktop.border.withValues(alpha: 0.7)),
            _ContactRow(
              desktopChrome: true,
              icon: Icons.phone_outlined,
              label: 'Телефон',
              value: user.phone.trim().isNotEmpty ? user.phone : '—',
              verified: user.phone.trim().isNotEmpty && user.phoneVerified,
            ),
          ],
        ),
      );
    }
    return Card(
      color: AppColors.cardBg,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            _ContactRow(
              desktopChrome: false,
              icon: Icons.email_outlined,
              label: 'Электронная почта',
              value: (user.email != null && user.email!.trim().isNotEmpty) ? user.email! : '—',
              verified: user.email != null && user.email!.trim().isNotEmpty && user.emailVerified,
            ),
            const Divider(height: 1),
            _ContactRow(
              desktopChrome: false,
              icon: Icons.phone_outlined,
              label: 'Телефон',
              value: user.phone.trim().isNotEmpty ? user.phone : '—',
              verified: user.phone.trim().isNotEmpty && user.phoneVerified,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrgTile extends StatelessWidget {
  const _OrgTile({required this.desktopChrome, required this.orgName});

  final bool desktopChrome;
  final String orgName;

  @override
  Widget build(BuildContext context) {
    if (desktopChrome) {
      return Container(
        decoration: BoxDecoration(
          color: AppColorsDesktop.surface,
          borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
          border: Border.all(color: AppColorsDesktop.border),
          boxShadow: DesktopDesignSystem.shadowCard,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Icon(Icons.business_rounded, color: AppColorsDesktop.primary.withValues(alpha: 0.85)),
          title: Text('Основная организация', style: DesktopDesignSystem.body.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(orgName, style: DesktopDesignSystem.body),
          ),
        ),
      );
    }
    return ListTile(
      tileColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: const Icon(Icons.business_rounded, color: AppColors.textSecondary),
      title: const Text('Основная организация'),
      subtitle: Text(orgName),
    );
  }
}

class _InvitationsTile extends StatelessWidget {
  const _InvitationsTile({
    required this.desktopChrome,
    required this.pending,
    required this.onTap,
  });

  final bool desktopChrome;
  final int pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (desktopChrome) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColorsDesktop.surface,
              borderRadius: BorderRadius.circular(DesktopDesignSystem.radiusCard),
              border: Border.all(color: AppColorsDesktop.border),
              boxShadow: DesktopDesignSystem.shadowCard,
            ),
            child: Row(
              children: [
                Icon(Icons.mail_outline_rounded, color: AppColorsDesktop.primary.withValues(alpha: 0.9)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Входящие приглашения', style: DesktopDesignSystem.sectionTitle.copyWith(fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(
                        'Принять или отклонить приглашение в организацию',
                        style: DesktopDesignSystem.bodySecondary,
                      ),
                    ],
                  ),
                ),
                InvitationCountBadge(
                  count: pending,
                  backgroundColor: AppColorsDesktop.error,
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: AppColorsDesktop.textTertiary),
              ],
            ),
          ),
        ),
      );
    }
    return ListTile(
      tileColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: const Icon(Icons.mail_outline_rounded, color: AppColors.textSecondary),
      title: const Text('Входящие приглашения'),
      subtitle: const Text('Принять или отклонить приглашение в организацию'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InvitationCountBadge(count: pending),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.desktopChrome,
    required this.icon,
    required this.label,
    required this.value,
    required this.verified,
  });

  final bool desktopChrome;
  final IconData icon;
  final String label;
  final String value;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final d = desktopChrome;
    final hasValue = value.trim().isNotEmpty && value != '—';
    final iconC = d ? AppColorsDesktop.textSecondary : AppColors.textSecondary;
    final valueC = d ? AppColorsDesktop.textPrimary : AppColors.textPrimary;
    final tertiary = d ? AppColorsDesktop.textTertiary : AppColors.textTertiary;

    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: d ? 20 : 16, vertical: d ? 10 : 4),
      leading: Icon(icon, color: iconC),
      title: Text(label, style: d ? DesktopDesignSystem.body.copyWith(fontWeight: FontWeight.w500) : null),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: valueC,
          ),
        ),
      ),
      trailing: hasValue
          ? verified
              ? Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0x1A059669),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF059669),
                    size: 18,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.help_outline_rounded,
                    color: tertiary,
                    size: 22,
                  ),
                )
          : null,
    );
  }
}
