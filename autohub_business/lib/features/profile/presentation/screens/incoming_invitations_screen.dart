import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/repositories/staff_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/staff_invitation_model.dart';

class IncomingInvitationsScreen extends ConsumerStatefulWidget {
  const IncomingInvitationsScreen({super.key});

  @override
  ConsumerState<IncomingInvitationsScreen> createState() => _IncomingInvitationsScreenState();
}

class _IncomingInvitationsScreenState extends ConsumerState<IncomingInvitationsScreen> {
  bool _loading = true;
  List<StaffInvitation> _items = const [];
  /// После принятия переключить активную организацию на пригласившую.
  bool _setActiveOrganizationOnAccept = true;

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
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Входящие приглашения')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Text(
                    'Приглашений нет',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length + 1,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Сделать основной организацией'),
                          subtitle: const Text(
                            'После принятия приглашения откроется работа в этой организации',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          value: _setActiveOrganizationOnAccept,
                          onChanged: (v) => setState(() => _setActiveOrganizationOnAccept = v),
                        );
                      }
                      final item = _items[i - 1];
                      return Card(
                        color: AppColors.cardBg,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.organizationName ?? 'Организация',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text('Роль: ${item.role.label}', style: const TextStyle(color: AppColors.textSecondary)),
                              if ((item.message ?? '').isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(item.message!, style: const TextStyle(color: AppColors.textSecondary)),
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
                                    child: ElevatedButton(
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
        SnackBar(content: Text(err.message), backgroundColor: AppColors.error),
      );
      return;
    }
    await ref.read(authProvider.notifier).refreshProfile();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Приглашение принято'), backgroundColor: AppColors.cardBg),
    );
  }

  Future<void> _decline(StaffInvitation item) async {
    final r = await ref.read(staffRepositoryProvider.notifier).declineIncomingInvitation(item.id);
    if (!mounted) return;
    final err = r.errorOrNull;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.message), backgroundColor: AppColors.error),
      );
      return;
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Приглашение отклонено'), backgroundColor: AppColors.cardBg),
    );
  }
}
