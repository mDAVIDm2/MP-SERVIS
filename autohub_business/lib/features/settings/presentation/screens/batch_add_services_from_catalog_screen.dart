import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/services/api_services_providers.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/service_catalog_models.dart';
import '../widgets/service_catalog_browser.dart';

class _PendingLine {
  _PendingLine({
    required this.cat,
    required this.item,
  })  : price = TextEditingController(),
        duration = TextEditingController(text: '${item.defaultDurationMinutes}');

  final ServiceCatalogCategoryRef cat;
  final ServiceCatalogItemRef item;
  final TextEditingController price;
  final TextEditingController duration;

  void dispose() {
    price.dispose();
    duration.dispose();
  }
}

/// Мобильный сценарий: набрать услуги из справочника, свернуть блок выбора, указать цены и сохранить разом.
class BatchAddServicesFromCatalogScreen extends ConsumerStatefulWidget {
  const BatchAddServicesFromCatalogScreen({super.key});

  @override
  ConsumerState<BatchAddServicesFromCatalogScreen> createState() =>
      _BatchAddServicesFromCatalogScreenState();
}

class _BatchAddServicesFromCatalogScreenState extends ConsumerState<BatchAddServicesFromCatalogScreen> {
  final List<_PendingLine> _pending = [];
  bool _catalogExpanded = true;

  Set<String> get _existingCatalogIds {
    return ref.read(settingsRepositoryProvider).services.map((s) => s.catalogItemId).whereType<String>().toSet();
  }

  Set<String> get _blockedIds {
    return {..._existingCatalogIds, ..._pending.map((p) => p.item.id)};
  }

  void _add(ServiceCatalogCategoryRef cat, ServiceCatalogItemRef item) {
    if (_blockedIds.contains(item.id)) return;
    setState(() {
      _pending.add(_PendingLine(cat: cat, item: item));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Добавлено: ${item.name}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _remove(int index) {
    setState(() {
      _pending.removeAt(index).dispose();
    });
  }

  @override
  void dispose() {
    for (final p in _pending) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _saveAll() async {
    if (_pending.isEmpty) return;
    final repo = ref.read(settingsRepositoryProvider.notifier);
    for (final p in _pending) {
      final rub = double.tryParse(p.price.text.replaceAll(',', '.')) ?? 0;
      final priceKopecks = (rub * 100).round();
      final dur = int.tryParse(p.duration.text) ?? p.item.defaultDurationMinutes;
      final catId = repo.categoryIdForCatalogCategory(p.cat);
      repo.addServiceFromCatalog(
        categoryId: catId,
        catalogItemId: p.item.id,
        name: p.item.name,
        priceKopecks: priceKopecks,
        durationMinutes: dur,
        requiredSkill: p.item.requiredSkill,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Сохранено услуг: ${_pending.length}')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(serviceCatalogDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Из справочника'),
      ),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Не удалось загрузить справочник.\nПроверьте сеть и попробуйте снова.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.95)),
            ),
          ),
        ),
        data: (data) {
          if (data.categories.isEmpty) {
            return const Center(child: Text('Справочник услуг пуст'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ExpansionTile(
                initiallyExpanded: _catalogExpanded,
                onExpansionChanged: (v) => setState(() => _catalogExpanded = v),
                title: const Text(
                  'Справочник MP-Servis',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _catalogExpanded
                      ? 'Поиск или вкладки разделов — нажмите услугу, чтобы добавить в список'
                      : 'Разверните, чтобы добавить ещё',
                  style: const TextStyle(fontSize: 13),
                ),
                children: [
                  SizedBox(
                    height: 360,
                    child: ServiceCatalogBrowser(
                      data: data,
                      onItemTap: _add,
                      alreadyAddedCatalogItemIds: _blockedIds,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_pending.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Выберите услуги из справочника выше',
                      style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.9)),
                    ),
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Цены и длительность (${_pending.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _catalogExpanded = true),
                      icon: const Icon(Icons.unfold_more_rounded, size: 20),
                      label: const Text('Ещё из справочника'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Укажите цену в ₽ и длительность для каждой позиции, затем сохраните.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                ...List.generate(_pending.length, (i) {
                  final p = _pending[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.item.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      p.cat.categoryName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _remove(i),
                                icon: const Icon(Icons.close_rounded),
                                tooltip: 'Убрать',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: p.price,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Цена, ₽',
                              hintText: '0',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: p.duration,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Длительность, мин',
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _saveAll,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Сохранить все в прайс'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          );
        },
      ),
    );
  }
}
