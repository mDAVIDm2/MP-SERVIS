import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/services/api_services_providers.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/service_catalog_browser.dart';

/// Полноэкранный выбор одной позиции из справочника (для экрана редактирования услуги).
class ServiceCatalogPickScreen extends ConsumerWidget {
  const ServiceCatalogPickScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(serviceCatalogDataProvider);
    final existingIds = ref.watch(settingsRepositoryProvider).services.map((s) => s.catalogItemId).whereType<String>().toSet();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Выбор из справочника'),
      ),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Не удалось загрузить справочник.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.95)),
            ),
          ),
        ),
        data: (data) {
          if (data.categories.isEmpty) {
            return const Center(child: Text('Справочник пуст'));
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ServiceCatalogBrowser(
              data: data,
              alreadyAddedCatalogItemIds: existingIds,
              onItemTap: (cat, item) {
                if (existingIds.contains(item.id)) return;
                Navigator.pop(context, (cat, item));
              },
            ),
          );
        },
      ),
    );
  }
}
