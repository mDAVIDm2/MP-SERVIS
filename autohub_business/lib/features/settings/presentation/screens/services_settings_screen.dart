import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/repositories/settings_repository.dart';
import 'services_settings_desktop_screen.dart';
import '../../../../shared/models/settings_models.dart';
import '../../../../core/utils/formatters.dart';
import 'service_category_edit_screen.dart';
import 'service_item_edit_screen.dart';
import 'service_packages_screen.dart';

class ServicesSettingsScreen extends ConsumerWidget {
  const ServicesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isDesktopPlatform) {
      return const ServicesSettingsDesktopScreen();
    }
    final state = ref.watch(settingsRepositoryProvider);
    final repo = ref.read(settingsRepositoryProvider.notifier);
    final categories = List<ServiceCategory>.from(state.categories)
      ..sort((a, b) => a.order.compareTo(b.order));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Услуги и цены'),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: 'Комплексы',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ServicePackagesScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...categories.map((cat) {
            final services = repo.servicesForCategory(cat.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    title: Text(
                      cat.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${services.length} услуг',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 22),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ServiceCategoryEditScreen(category: cat),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () =>
                              _openAddService(context, ref, cat.id),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                          ),
                          onPressed: () =>
                              _confirmDeleteCategory(context, ref, cat),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ServiceListScreen(category: cat),
                      ),
                    ),
                  ),
                  if (services.isNotEmpty)
                    ...services
                        .take(3)
                        .map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: 8,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    s.name,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                Text(
                                  formatMoney(s.priceKopecks),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _durationStr(s.durationMinutes),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  if (services.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 8),
                      child: Text(
                        'и ещё ${services.length - 3}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddCategory(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _durationStr(int min) {
    if (min < 60) return '$min мин';
    final h = min ~/ 60;
    final m = min % 60;
    if (m == 0) return '$h ч';
    return '$h ч $m мин';
  }

  void _openAddCategory(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая категория'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Название',
            hintText: 'Например: Кузовной ремонт',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(settingsRepositoryProvider.notifier).addCategory(name);
                if (context.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(
    BuildContext context,
    WidgetRef ref,
    ServiceCategory cat,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить категорию?'),
        content: Text(
          'Категория «${cat.name}» и все услуги в ней будут удалены.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              ref
                  .read(settingsRepositoryProvider.notifier)
                  .deleteCategory(cat.id);
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _openAddService(BuildContext context, WidgetRef ref, String categoryId) {
    final cat = ref
        .read(settingsRepositoryProvider)
        .categories
        .firstWhere((c) => c.id == categoryId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceItemEditScreen(
          categoryId: categoryId,
          categoryName: cat.name,
        ),
      ),
    );
  }
}

class ServiceListScreen extends ConsumerWidget {
  final ServiceCategory category;

  const ServiceListScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(settingsRepositoryProvider);
    final repo = ref.read(settingsRepositoryProvider.notifier);
    final services = repo.servicesForCategory(category.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(category.name)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: services.length,
        itemBuilder: (context, i) {
          final s = services[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(s.name),
              subtitle: Text(
                '${formatMoney(s.priceKopecks)} • ${s.durationMinutes} мин',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ServiceItemEditScreen(
                          categoryId: category.id,
                          categoryName: category.name,
                          existing: s,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                    ),
                    onPressed: () {
                      ref
                          .read(settingsRepositoryProvider.notifier)
                          .deleteService(s.id);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceItemEditScreen(
              categoryId: category.id,
              categoryName: category.name,
            ),
          ),
        ),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
}
