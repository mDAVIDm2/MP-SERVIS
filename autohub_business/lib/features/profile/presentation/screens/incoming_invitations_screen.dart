import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/staff_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../core/theme/desktop_light_theme.dart';
import '../../../../shared/models/staff_invitation_model.dart';
import '../providers/pending_invitations_count_provider.dart';

class IncomingInvitationsScreen extends ConsumerStatefulWidget {
  const IncomingInvitationsScreen({super.key, this.desktopChrome = false});

  /// Светлая тема как у остальных десктоп-экранов.
  final bool desktopChrome;

  @override
  ConsumerState<IncomingInvitationsScreen> createState() => _IncomingInvitationsScreenState();
}

class _IncomingInvitationsScreenState extends ConsumerState<IncomingInvitationsScreen> {
  bool _loading = true;
  List<StaffInvitation> _items = const [];
  /// После принятия переключить активную организацию на пригласившую.
  bool _setActiveOrganizationOnAccept = true;

  bool get _d => widget.desktopChrome;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await ref.read(staffRepositoryProvider.notifier).getIncomingInvitations();
    if (!mounted) return;
    final data = r.dataOrNull;
    if (data != null) {
      setState(() {
        _items = data;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = false);
    final e = r.errorOrNull;
    if (e != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: _d ? AppColorsDesktop.error : AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _d ? AppColorsDesktop.background : AppColors.background;
    final cardBg = _d ? AppColorsDesktop.surface : AppColors.cardBg;
    final textPri = _d ? AppColorsDesktop.textPrimary : AppColors.textPrimary;
    final textSec = _d ? AppColorsDesktop.textSecondary : AppColors.textSecondary;
    final border = _d ? AppColorsDesktop.border : AppColors.border;

    final scaffold = Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Входящие приглашения'),
        backgroundColor: _d ? AppColorsDesktop.surface : null,
        foregroundColor: _d ? AppColorsDesktop.textPrimary : null,
        surfaceTintColor: _d ? Colors.transparent : null,
        elevation: _d ? 0 : null,
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: _d ? AppColorsDesktop.primary : AppColors.primary,
              ),
            )
          : _items.isEmpty
              ? Center(
                  child: Text(
                    'Приглашений нет',
                    style: TextStyle(color: textSec),
                  ),
                )
              : RefreshIndicator(
                  color: _d ? AppColorsDesktop.primary : AppColors.primary,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length + 1,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Сделать основной организацией', style: TextStyle(color: textPri)),
                          subtitle: Text(
                            'После принятия приглашения откроется работа в этой организации',
                            style: TextStyle(fontSize: 13, color: textSec),
                          ),
                          value: _setActiveOrganizationOnAccept,
                          onChanged: (v) => setState(() => _setActiveOrganizationOnAccept = v),
                        );
                      }
                      final item = _items[i - 1];
                      return Card(
                        color: cardBg,
                        elevation: _d ? 0 : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_d ? DesktopDesignSystem.radiusCard : 12),
                          side: _d ? BorderSide(color: border) : BorderSide.none,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.organizationName ?? 'Организация',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: textPri,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text('Роль: ${item.role.label}', style: TextStyle(color: textSec)),
                              if ((item.message ?? '').isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(item.message!, style: TextStyle(color: textSec)),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _decline(item),
                                      child: const Text('Отклонить'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () => _accept(item),
                                      child: const Text('Принять'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
    if (_d) return themeDesktopLight(child: scaffold);
    return scaffold;
  }

  Future<void> _accept(StaffInvitation item) async {
    final r = await ref.read(staffRepositoryProvider.notifier).acceptIncomingInvitation(
          item.id,
          setActiveOrganization: _setActiveOrganizationOnAccept,
        );
    if (!mounted) return;
    final err = r.errorOrNull;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.message),
          backgroundColor: _d ? AppColorsDesktop.error : AppColors.error,
        ),
      );
      return;
    }
    await ref.read(authProvider.notifier).refreshProfile();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Приглашение принято'),
        backgroundColor: _d ? AppColorsDesktop.nestedBg : AppColors.cardBg,
      ),
    );
  }

  Future<void> _decline(StaffInvitation item) async {
    final r = await ref.read(staffRepositoryProvider.notifier).declineIncomingInvitation(item.id);
    if (!mounted) return;
    final err = r.errorOrNull;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.message),
          backgroundColor: _d ? AppColorsDesktop.error : AppColors.error,
        ),
      );
      return;
    }
    ref.invalidate(pendingInvitationsCountProvider);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Приглашение отклонено'),
        backgroundColor: _d ? AppColorsDesktop.nestedBg : AppColors.cardBg,
      ),
    );
  }
}
