import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/internal_data_providers.dart';
import '../../../core/constants/labels_ru.dart';
import '../../../core/theme/app_colors.dart';
import '../sections/section_scaffold.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(usersProvider);
    return SectionScaffold(
      title: 'Пользователи',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          async.when(
            data: (items) {
              final business = items.where((e) => (e['account_type'] ?? '') == 'business').toList();
              final clients = items.where((e) => (e['account_type'] ?? '') != 'business').toList();
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: TabBar(
                  controller: _tabController,
                  onTap: (_) => setState(() {}),
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: AppColors.primary.withValues(alpha: 0.12),
                  ),
                  tabs: [
                    Tab(text: 'Бизнес-аккаунты (${business.length})'),
                    Tab(text: 'Клиенты (${clients.length})'),
                  ],
                ),
              );
            },
            loading: () => const SizedBox(height: 48),
            error: (_, __) => const SizedBox(height: 48),
          ),
          const SizedBox(height: 16),
          async.when(
            data: (items) {
              final business = items.where((e) => (e['account_type'] ?? '') == 'business').toList();
              final clients = items.where((e) => (e['account_type'] ?? '') != 'business').toList();
              final idx = _tabController.index.clamp(0, 1);
              final list = idx == 0 ? business : clients;
              final label = idx == 0 ? 'Бизнес' : 'Клиент';
              return _UserList(items: list, typeLabel: label);
            },
            loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Ошибка загрузки: $e', style: const TextStyle(color: AppColors.danger)),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  const _UserList({required this.items, required this.typeLabel});

  final List<Map<String, dynamic>> items;
  final String typeLabel;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Нет $typeLabel пользователей',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final e = items[index];
        final name = e['name'] as String? ?? '—';
        final phone = e['phone'] as String? ?? '—';
        final roleLabel = e['role_label'] as String? ?? LabelsRu.userRole(e['role'] as String?);
        final orgName = e['organization_name'] as String? ?? '';
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: typeLabel == 'Бизнес'
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.textSecondary.withValues(alpha: 0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: typeLabel == 'Бизнес' ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (orgName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$roleLabel · $orgName',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else
                      Text(
                        roleLabel,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
