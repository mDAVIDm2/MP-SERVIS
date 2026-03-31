import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/settings_models.dart';

class ServicePackagesScreen extends ConsumerWidget {
  const ServicePackagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsRepositoryProvider);
    final repo = ref.read(settingsRepositoryProvider.notifier);
    final categories = List<ServiceCategory>.from(state.categories)
      ..sort((a, b) => a.order.compareTo(b.order));
    final servicesById = {for (final s in state.services) s.id: s};

    return Scaffold(
      appBar: AppBar(title: const Text('Комплексы услуг')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...categories.map((cat) {
            final packs = repo.packagesForCategory(cat.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                title: Text(cat.name),
                subtitle: Text('${packs.length} комплексов'),
                children: [
                  ...packs.map((p) {
                    final regular = p.includedServiceIds
                        .map((id) => servicesById[id]?.priceKopecks ?? 0)
                        .fold(0, (a, b) => a + b);
                    final save = regular - p.packagePriceKopecks;
                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text(
                        '${formatMoney(p.packagePriceKopecks)}  •  Экономия: ${save > 0 ? formatMoney(save) : '—'}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => repo.deletePackage(p.id),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ServicePackageEditScreen(
                            category: cat,
                            existing: p,
                          ),
                        ),
                      ),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ServicePackageEditScreen(category: cat),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить комплекс'),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class ServicePackageEditScreen extends ConsumerStatefulWidget {
  final ServiceCategory category;
  final ServicePackage? existing;

  const ServicePackageEditScreen({
    super.key,
    required this.category,
    this.existing,
  });

  @override
  ConsumerState<ServicePackageEditScreen> createState() =>
      _ServicePackageEditScreenState();
}

class _ServicePackageEditScreenState
    extends ConsumerState<ServicePackageEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  final Set<String> _included = {};
  final Map<String, TextEditingController> _addonPriceCtrls = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _priceController = TextEditingController(
      text: widget.existing != null
          ? (widget.existing!.packagePriceKopecks / 100).toStringAsFixed(0)
          : '',
    );
    _included.addAll(widget.existing?.includedServiceIds ?? const []);
    for (final a in widget.existing?.addons ?? const <ServicePackageAddon>[]) {
      _addonPriceCtrls[a.serviceId] = TextEditingController(
        text: (a.extraPriceKopecks / 100).toStringAsFixed(0),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    for (final c in _addonPriceCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = ref
        .read(settingsRepositoryProvider.notifier)
        .servicesForCategory(widget.category.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Новый комплекс' : 'Редактировать комплекс',
        ),
        actions: [TextButton(onPressed: _save, child: const Text('Сохранить'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Название комплекса'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Цена комплекса, ₽'),
          ),
          const SizedBox(height: 20),
          const Text(
            'Что входит в комплекс',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...services.map(
            (s) => CheckboxListTile(
              value: _included.contains(s.id),
              title: Text(s.name),
              subtitle: Text(formatMoney(s.priceKopecks)),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _included.add(s.id);
                  } else {
                    _included.remove(s.id);
                  }
                });
              },
            ),
          ),
          const Divider(height: 24),
          const Text(
            'Доп. услуги для комплекса',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...services.map((s) {
            final selected = _addonPriceCtrls.containsKey(s.id);
            final ctrl = _addonPriceCtrls.putIfAbsent(
              s.id,
              () => TextEditingController(text: '0'),
            );
            return Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(s.name)),
                        Switch(
                          value: selected,
                          onChanged: (v) {
                            setState(() {
                              if (v) {
                                _addonPriceCtrls[s.id] = ctrl;
                              } else {
                                _addonPriceCtrls.remove(s.id)?.dispose();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    if (_addonPriceCtrls.containsKey(s.id))
                      TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Доплата, ₽ (например 300)',
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final price =
        (double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0) *
        100;
    final addons = <ServicePackageAddon>[];
    for (final e in _addonPriceCtrls.entries) {
      final rub = double.tryParse(e.value.text.replaceAll(',', '.')) ?? 0;
      addons.add(
        ServicePackageAddon(
          serviceId: e.key,
          extraPriceKopecks: (rub * 100).round(),
        ),
      );
    }
    final repo = ref.read(settingsRepositoryProvider.notifier);
    final data = ServicePackage(
      id: widget.existing?.id ?? 'pkg_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      categoryId: widget.category.id,
      packagePriceKopecks: price.round(),
      includedServiceIds: _included.toList(),
      addons: addons,
    );
    if (widget.existing == null) {
      repo.addPackage(data);
    } else {
      repo.updatePackage(data);
    }
    Navigator.pop(context);
  }
}
