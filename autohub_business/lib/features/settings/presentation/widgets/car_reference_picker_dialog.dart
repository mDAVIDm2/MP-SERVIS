import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/services/api_services_providers.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_design_system.dart';
import '../../../../core/theme/desktop_light_theme.dart';
import '../../../../shared/models/car_reference_models.dart';

/// Диалог выбора марки / модели / поколения из справочника БД MP-Servis.
class CarReferencePickerDialog extends ConsumerStatefulWidget {
  const CarReferencePickerDialog({super.key, required this.onPick});

  final void Function(String label) onPick;

  static Future<void> show(BuildContext context, WidgetRef ref) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black38,
      builder: (ctx) => themeDesktopLight(
        child: CarReferencePickerDialog(
          onPick: (label) => ref.read(settingsRepositoryProvider.notifier).addBrand(label),
        ),
      ),
    );
  }

  @override
  ConsumerState<CarReferencePickerDialog> createState() => _CarReferencePickerDialogState();
}

class _CarReferencePickerDialogState extends ConsumerState<CarReferencePickerDialog> {
  String _brandQuery = '';
  CarBrandRef? _brand;

  @override
  Widget build(BuildContext context) {
    final brandsAsync = ref.watch(carReferenceBrandsProvider);

    return AlertDialog(
      title: const Text('Справочник марок и моделей'),
      content: SizedBox(
        width: 720,
        height: 440,
        child: brandsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e, _) => SelectableText(
            'Не удалось загрузить марки: $e\n\nПроверьте API и эндпоинт GET /reference/car-brands.',
            style: const TextStyle(color: AppColorsDesktop.error, fontSize: 13),
          ),
          data: (brands) {
            final q = _brandQuery.trim().toLowerCase();
            final filtered = q.isEmpty
                ? brands
                : brands.where((b) => b.name.toLowerCase().contains(q)).toList();
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Поиск марки…',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _brandQuery = v),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final b = filtered[i];
                            final sel = _brand?.id == b.id;
                            return Material(
                              color: sel ? AppColorsDesktop.primary.withValues(alpha: 0.1) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => setState(() => _brand = b),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  child: Text(
                                    b.name,
                                    style: TextStyle(
                                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                      color: AppColorsDesktop.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 6,
                  child: _brand == null
                      ? Center(
                          child: Text(
                            'Выберите марку слева',
                            style: DesktopDesignSystem.bodySecondary,
                          ),
                        )
                      : _BrandDetailPanel(
                          brand: _brand!,
                          onPick: widget.onPick,
                        ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
      ],
    );
  }
}

class _BrandDetailPanel extends ConsumerWidget {
  const _BrandDetailPanel({required this.brand, required this.onPick});

  final CarBrandRef brand;
  final void Function(String label) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(carReferenceModelsProvider(brand.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(brand.name, style: DesktopDesignSystem.sectionTitle),
        const SizedBox(height: 4),
        Text(
          'Добавьте марку целиком или конкретные модели — в прайс попадут те же названия, что в общей базе.',
          style: DesktopDesignSystem.meta.copyWith(height: 1.35),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => onPick(brand.name),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Добавить марку целиком'),
        ),
        const SizedBox(height: 12),
        Text('Модели', style: DesktopDesignSystem.label),
        const SizedBox(height: 6),
        Expanded(
          child: modelsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Text('Модели: $e', style: const TextStyle(fontSize: 12, color: AppColorsDesktop.error)),
            data: (models) {
              if (models.isEmpty) {
                return Text(
                  'Для этой марки нет моделей в БД — используйте кнопку выше.',
                  style: DesktopDesignSystem.bodySecondary,
                );
              }
              return ListView.builder(
                itemCount: models.length,
                itemBuilder: (_, i) {
                  final m = models[i];
                  return _ModelExpansionTile(
                    brandName: brand.name,
                    model: m,
                    onPick: onPick,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ModelExpansionTile extends ConsumerStatefulWidget {
  const _ModelExpansionTile({
    required this.brandName,
    required this.model,
    required this.onPick,
  });

  final String brandName;
  final CarModelRef model;
  final void Function(String label) onPick;

  @override
  ConsumerState<_ModelExpansionTile> createState() => _ModelExpansionTileState();
}

class _ModelExpansionTileState extends ConsumerState<_ModelExpansionTile> {
  bool _expanded = false;

  String _labelBrandModel() => '${widget.brandName} · ${widget.model.name}';

  String _labelFull(String generationName) => '${widget.brandName} · ${widget.model.name} · $generationName';

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: AppColorsDesktop.nestedBg.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColorsDesktop.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(widget.model.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        trailing: TextButton(
          onPressed: () => widget.onPick(_labelBrandModel()),
          child: const Text('Модель'),
        ),
        onExpansionChanged: (open) => setState(() => _expanded = open),
        children: [
          if (_expanded)
            Consumer(
              builder: (ctx, ref, _) {
                final genAsync = ref.watch(carReferenceGenerationsProvider(widget.model.id));
                return genAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('Поколения: $e', style: const TextStyle(fontSize: 12, color: AppColorsDesktop.error)),
                  ),
                  data: (gens) {
                    if (gens.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Поколений нет — достаточно кнопки «Модель».',
                          style: DesktopDesignSystem.meta,
                        ),
                      );
                    }
                    return Column(
                      children: gens
                          .map(
                            (g) => ListTile(
                              dense: true,
                              title: Text(g.name, style: const TextStyle(fontSize: 13)),
                              subtitle: g.subtitle.isEmpty
                                  ? null
                                  : Text(g.subtitle, style: DesktopDesignSystem.meta),
                              trailing: TextButton(
                                onPressed: () => widget.onPick(_labelFull(g.name)),
                                child: const Text('Добавить'),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
