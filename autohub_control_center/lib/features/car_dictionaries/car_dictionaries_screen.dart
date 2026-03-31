import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/api/internal_data_providers.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../sections/section_scaffold.dart';

class CarDictionariesScreen extends ConsumerStatefulWidget {
  const CarDictionariesScreen({super.key});

  @override
  ConsumerState<CarDictionariesScreen> createState() => _CarDictionariesScreenState();
}

class _CarDictionariesScreenState extends ConsumerState<CarDictionariesScreen> {
  final _brandNameController = TextEditingController();
  final _modelNameController = TextEditingController();
  final _generationNameController = TextEditingController();
  int? _addingModelBrandId;
  int? _addingGenerationModelId;

  @override
  void dispose() {
    _brandNameController.dispose();
    _modelNameController.dispose();
    _generationNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brandsAsync = ref.watch(carBrandsProvider);
    final pendingAsync = ref.watch(pendingCarProvider);
    return SectionScaffold(
      title: 'Авто-справочники',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Заявки на добавление'),
            pendingAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return _card(
                    child: const Text('Нет заявок', style: TextStyle(color: AppColors.textSecondary)),
                  );
                }
                return _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: items.map((e) => _pendingTile(e)).toList(),
                  ),
                );
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (e, _) => _card(child: Text('Ошибка: $e', style: const TextStyle(color: AppColors.danger))),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Марки, модели, поколения'),
            brandsAsync.when(
              data: (brands) {
                if (brands.isEmpty) {
                  return _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Нет марок', style: TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 12),
                        _addBrandField(),
                      ],
                    ),
                  );
                }
                return _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...brands.map((b) => _brandTile(b)),
                      const SizedBox(height: 12),
                      _addBrandField(),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (e, _) => _card(child: Text('Ошибка: $e', style: const TextStyle(color: AppColors.danger))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _pendingTile(Map<String, dynamic> e) {
    final id = e['id'] as String? ?? '';
    // Бэкенд отдаёт camelCase: pendingBrand, pendingModel, pendingGeneration, createdAt
    final brand = (e['pendingBrand'] ?? e['pending_brand']) as String?;
    final model = (e['pendingModel'] ?? e['pending_model']) as String?;
    final gen = (e['pendingGeneration'] ?? e['pending_generation']) as String?;
    final createdAt = e['createdAt'] ?? e['created_at'];
    final dateStr = createdAt != null ? _formatDate(createdAt) : '';
    final brandStr = brand?.trim().isNotEmpty == true ? brand! : '—';
    final modelStr = model?.trim().isNotEmpty == true ? model! : '(не указана)';
    final genStr = gen?.trim().isNotEmpty == true ? gen! : '—';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Марка: $brandStr · Модель: $modelStr · Поколение: $genStr',
                  style: const TextStyle(fontSize: 14),
                ),
                if (dateStr.isNotEmpty) Text(dateStr, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              final ok = await ref.read(internalApiProvider).approvePendingCar(id);
              if (context.mounted && ok) {
                ref.invalidate(pendingCarProvider);
                ref.invalidate(carBrandsProvider);
              }
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Подтвердить'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => _showSuggestFromList(context, id),
            icon: const Icon(Icons.list_alt, size: 18),
            label: const Text('Предложить из списка'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () async {
              final ok = await ref.read(internalApiProvider).rejectPendingCar(id);
              if (context.mounted && ok) ref.invalidate(pendingCarProvider);
            },
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Отклонить'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          ),
        ],
      ),
    );
  }

  void _showSuggestFromList(BuildContext context, String pendingId) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _SuggestFromListDialog(
        pendingId: pendingId,
        onSent: () {
          ref.invalidate(pendingCarProvider);
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String title, String message, VoidCallback onConfirm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) onConfirm();
  }

  Widget _brandTile(Map<String, dynamic> brand) {
    final id = brand['id'] as int? ?? 0;
    final name = brand['name'] as String? ?? '';
    return ExpansionTile(
      title: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
            tooltip: 'Удалить марку',
            onPressed: () => _confirmDelete(
              context,
              'Удалить марку?',
              'Марка «$name» и все её модели и поколения будут удалены.',
              () async {
                final ok = await ref.read(internalApiProvider).deleteCarBrand(id);
                if (mounted && ok) ref.invalidate(carBrandsProvider);
              },
            ),
          ),
        ],
      ),
      controlAffinity: ListTileControlAffinity.leading,
      children: [
        Consumer(
          builder: (context, ref, _) {
            final modelsAsync = ref.watch(carModelsProvider(id));
            return modelsAsync.when(
              data: (models) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (models.isNotEmpty)
                    ...models.map((m) => _modelTile(id, m)),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8),
                    child: _addingModelBrandId == id
                        ? Row(
                            children: [
                              SizedBox(
                                width: 200,
                                child: TextField(
                                  controller: _modelNameController,
                                  decoration: const InputDecoration(labelText: 'Название модели', isDense: true),
                                  onSubmitted: (_) => _submitModel(id),
                                ),
                              ),
                              IconButton(icon: const Icon(Icons.check), onPressed: () => _submitModel(id)),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(() => _addingModelBrandId = null),
                              ),
                            ],
                          )
                        : TextButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Добавить модель'),
                            onPressed: () => setState(() => _addingModelBrandId = id),
                          ),
                  ),
                ],
              ),
              loading: () => const Padding(padding: EdgeInsets.all(16), child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))),
              error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('Ошибка: $e', style: const TextStyle(color: AppColors.danger, fontSize: 12))),
            );
          },
        ),
      ],
    );
  }

  Widget _modelTile(int brandId, Map<String, dynamic> model) {
    final id = model['id'] as int? ?? 0;
    final name = model['name'] as String? ?? '';
    return ExpansionTile(
      title: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 14))),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
            tooltip: 'Удалить модель',
            onPressed: () => _confirmDelete(
              context,
              'Удалить модель?',
              'Модель «$name» и все её поколения будут удалены.',
              () async {
                final ok = await ref.read(internalApiProvider).deleteCarModel(id);
                if (mounted && ok) ref.invalidate(carModelsProvider(brandId));
              },
            ),
          ),
        ],
      ),
      controlAffinity: ListTileControlAffinity.leading,
      children: [
        Consumer(
          builder: (context, ref, _) {
            final gensAsync = ref.watch(carGenerationsProvider(id));
            return gensAsync.when(
              data: (gens) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (gens.isNotEmpty)
                    ...gens.map((g) {
                      final gId = g['id'] as int? ?? 0;
                      final gName = g['name'] as String? ?? '';
                      final modelId = id;
                      return ListTile(
                        dense: true,
                        title: Text('$gName${g['year_from'] != null ? ' (${g['year_from']}–${g['year_to'] ?? "н.в."})' : ''}', style: const TextStyle(fontSize: 13)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                          tooltip: 'Удалить поколение',
                          onPressed: () => _confirmDelete(
                            context,
                            'Удалить поколение?',
                            'Поколение «$gName» будет удалено.',
                            () async {
                              final ok = await ref.read(internalApiProvider).deleteCarGeneration(gId);
                              if (mounted && ok) ref.invalidate(carGenerationsProvider(modelId));
                            },
                          ),
                        ),
                      );
                    }),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8),
                    child: _addingGenerationModelId == id
                        ? Row(
                            children: [
                              SizedBox(
                                width: 180,
                                child: TextField(
                                  controller: _generationNameController,
                                  decoration: const InputDecoration(labelText: 'Поколение', isDense: true),
                                  onSubmitted: (_) => _submitGeneration(id),
                                ),
                              ),
                              IconButton(icon: const Icon(Icons.check), onPressed: () => _submitGeneration(id)),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(() => _addingGenerationModelId = null),
                              ),
                            ],
                          )
                        : TextButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Добавить поколение'),
                            onPressed: () => setState(() => _addingGenerationModelId = id),
                          ),
                  ),
                ],
              ),
              loading: () => const Padding(padding: EdgeInsets.all(16), child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))),
              error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('Ошибка: $e', style: const TextStyle(color: AppColors.danger, fontSize: 12))),
            );
          },
        ),
      ],
    );
  }

  Future<void> _submitModel(int brandId) async {
    final name = _modelNameController.text.trim();
    if (name.isEmpty) return;
    final created = await ref.read(internalApiProvider).createCarModel(brandId, name);
    if (mounted && created != null) {
      _modelNameController.clear();
      setState(() => _addingModelBrandId = null);
      ref.invalidate(carModelsProvider(brandId));
    }
  }

  Future<void> _submitGeneration(int modelId) async {
    final name = _generationNameController.text.trim();
    if (name.isEmpty) return;
    final created = await ref.read(internalApiProvider).createCarGeneration(modelId, name);
    if (mounted && created != null) {
      _generationNameController.clear();
      setState(() => _addingGenerationModelId = null);
      ref.invalidate(carGenerationsProvider(modelId));
    }
  }

  Widget _addBrandField() {
    return Row(
      children: [
        SizedBox(
          width: 220,
          child: TextField(
            controller: _brandNameController,
            decoration: const InputDecoration(labelText: 'Новая марка', isDense: true),
            onSubmitted: (_) => _submitBrand(),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _submitBrand,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Добавить марку'),
        ),
      ],
    );
  }

  Future<void> _submitBrand() async {
    final name = _brandNameController.text.trim();
    if (name.isEmpty) return;
    final created = await ref.read(internalApiProvider).createCarBrand(name);
    if (mounted && created != null) {
      _brandNameController.clear();
      ref.invalidate(carBrandsProvider);
    }
  }

  String _formatDate(dynamic v) {
    if (v == null) return '';
    if (v is String) {
      try {
        final d = DateTime.parse(v);
        return DateFormat('dd.MM.yyyy HH:mm').format(d);
      } catch (_) {}
    }
    return '$v';
  }
}

/// Диалог выбора марки, модели и поколения из справочника для отправки предложения пользователю.
class _SuggestFromListDialog extends ConsumerStatefulWidget {
  const _SuggestFromListDialog({required this.pendingId, required this.onSent});

  final String pendingId;
  final VoidCallback onSent;

  @override
  ConsumerState<_SuggestFromListDialog> createState() => _SuggestFromListDialogState();
}

class _SuggestFromListDialogState extends ConsumerState<_SuggestFromListDialog> {
  int? _brandId;
  int? _modelId;
  int? _generationId;
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final brandsAsync = ref.watch(carBrandsProvider);
    final modelsAsync = _brandId != null ? ref.watch(carModelsProvider(_brandId!)) : const AsyncValue.data([]);
    final gensAsync = _modelId != null ? ref.watch(carGenerationsProvider(_modelId!)) : const AsyncValue.data([]);
    final brands = brandsAsync.valueOrNull ?? [];
    final models = modelsAsync.valueOrNull ?? [];
    final generations = gensAsync.valueOrNull ?? [];

    return AlertDialog(
      title: const Text('Предложить из списка'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Выберите марку, модель и поколение для предложения пользователю.', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _brandId,
              decoration: const InputDecoration(labelText: 'Марка', border: OutlineInputBorder()),
              items: brands.map((b) => DropdownMenuItem<int>(value: b['id'] as int, child: Text(b['name'] as String? ?? ''))).toList(),
              onChanged: (v) => setState(() { _brandId = v; _modelId = null; _generationId = null; }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _modelId,
              decoration: const InputDecoration(labelText: 'Модель', border: OutlineInputBorder()),
              items: models.map((m) => DropdownMenuItem<int>(value: m['id'] as int, child: Text(m['name'] as String? ?? ''))).toList(),
              onChanged: _brandId == null ? null : (v) => setState(() { _modelId = v; _generationId = null; }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _generationId,
              decoration: const InputDecoration(labelText: 'Поколение', border: OutlineInputBorder()),
              items: generations.map((g) => DropdownMenuItem<int>(value: g['id'] as int, child: Text("${g['name']}${g['year_from'] != null ? ' (${g['year_from']}–${g['year_to'] ?? "н.в."})' : ''}"))).toList(),
              onChanged: _modelId == null ? null : (v) => setState(() => _generationId = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _sending ? null : () => Navigator.of(context).pop(), child: const Text('Отмена')),
        FilledButton(
          onPressed: (_sending || _brandId == null || _modelId == null || _generationId == null)
              ? null
              : () async {
                  setState(() => _sending = true);
                  final ok = await ref.read(internalApiProvider).suggestPendingCar(
                    widget.pendingId,
                    brandId: _brandId!,
                    modelId: _modelId!,
                    generationId: _generationId!,
                  );
                  if (context.mounted) {
                    setState(() => _sending = false);
                    if (ok) {
                      widget.onSent();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Предложение отправлено в уведомления пользователю.')));
                    }
                  }
                },
          child: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Отправить'),
        ),
      ],
    );
  }
}
