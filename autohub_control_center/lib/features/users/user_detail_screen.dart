import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/internal_data_providers.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/media_url_resolver.dart';
import '../../shared/widgets/cc_auth_network_image.dart';

class UserDetailScreen extends ConsumerStatefulWidget {
  const UserDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  final _nameEdit = TextEditingController();

  @override
  void dispose() {
    _nameEdit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userDetailProvider(widget.userId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Пользователь'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/app/users'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(userDetailProvider(widget.userId)),
          ),
        ],
      ),
      body: async.when(
        data: (u) {
          if (u == null) {
            return const Center(child: Text('Не найден', style: TextStyle(color: AppColors.textSecondary)));
          }
          return _body(context, u);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e', style: const TextStyle(color: AppColors.danger))),
      ),
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> u) {
    final name = u['name'] as String? ?? '—';
    final phoneRaw = u['phone'] as String? ?? '';
    final phone = phoneRaw.isNotEmpty ? phoneRaw : '—';
    final email = u['email'] as String? ?? '';
    final org = u['organization_name'] as String? ?? '';
    final roleLabel = u['role_label'] as String? ?? '';
    final avatarRaw = u['avatar_url'] as String?;
    final internalAvatar = internalAvatarImageUrl(avatarRaw);
    final cars = u['cars_from_orders'];
    final carList = cars is List ? cars : <dynamic>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (internalAvatar != null)
                        CcAuthNetworkImage(
                          url: internalAvatar,
                          width: 72,
                          height: 72,
                          borderRadius: BorderRadius.circular(36),
                          fit: BoxFit.cover,
                        )
                      else
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(phone, style: const TextStyle(color: AppColors.textSecondary)),
                            if (email.isNotEmpty) Text(email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            if (org.isNotEmpty)
                              Text('$roleLabel · $org', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))
                            else
                              Text(roleLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          _nameEdit.text = name != '—' ? name : '';
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Имя в системе'),
                              content: TextField(
                                controller: _nameEdit,
                                decoration: const InputDecoration(labelText: 'Имя'),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
                                FilledButton(
                                  onPressed: () async {
                                    final t = _nameEdit.text.trim();
                                    if (t.isEmpty) return;
                                    final ok = await ref.read(internalApiProvider).patchUser(widget.userId, name: t);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (mounted) {
                                      ref.invalidate(userDetailProvider(widget.userId));
                                      ref.invalidate(usersProvider);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(ok == null ? 'Ошибка' : 'Сохранено')),
                                      );
                                    }
                                  },
                                  child: const Text('Сохранить'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Изменить имя'),
                      ),
                      if (avatarRaw != null && avatarRaw.toString().isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await ref.read(internalApiProvider).patchUser(widget.userId, clearAvatar: true);
                            if (mounted) {
                              ref.invalidate(userDetailProvider(widget.userId));
                              ref.invalidate(usersProvider);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(ok == null ? 'Ошибка' : 'Аватар сброшен')),
                              );
                            }
                          },
                          icon: const Icon(Icons.hide_image_outlined, size: 18),
                          label: const Text('Убрать аватар'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Авто в заказах (${carList.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (carList.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Нет заказов с этим телефоном или телефон не указан в профиле.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...carList.map((raw) {
              if (raw is! Map) return const SizedBox.shrink();
              final c = Map<String, dynamic>.from(raw);
              final carId = c['car_id']?.toString() ?? '';
              final plate = c['license_plate']?.toString() ?? '';
              final vin = c['vin']?.toString() ?? '';
              final info = c['car_info']?.toString() ?? '';
              final n = c['orders_count']?.toString() ?? '';
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(info.isNotEmpty ? info : 'Авто $carId', maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    [
                      if (plate.isNotEmpty) 'Госномер: $plate',
                      if (vin.isNotEmpty) 'VIN: $vin',
                      if (n.isNotEmpty) 'Заказов: $n',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: carId.isEmpty || phoneRaw.isEmpty
                      ? null
                      : () => context.go('/app/client-cars/history?phone=${Uri.encodeComponent(phoneRaw)}&car_id=${Uri.encodeComponent(carId)}'),
                ),
              );
            }),
        ],
      ),
    );
  }
}
