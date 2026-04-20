import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/settings_models.dart';

int _packageListDurationMinutes(ServicePackage p, Map<String, ServiceItem> byId) {
  if (p.packageDurationMinutes > 0) return p.packageDurationMinutes;
  return p.includedServiceIds.fold<int>(0, (s, id) => s + (byId[id]?.durationMinutes ?? 0));
}

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Комплексы услуг'),
        backgroundColor: AppColors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...categories.map((cat) {
            final packs = repo.packagesForCategory(cat.id);
            return Card(
              color: AppColors.cardBg,
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                title: Text(cat.name, style: const TextStyle(color: AppColors.textPrimary)),
                subtitle: Text(
                  '${packs.length} комплексов',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                iconColor: AppColors.textSecondary,
                collapsedIconColor: AppColors.textSecondary,
                children: [
                  ...packs.map((p) {
                    final regular = p.includedServiceIds
                        .map((id) => servicesById[id]?.priceKopecks ?? 0)
                        .fold(0, (a, b) => a + b);
                    final save = regular - p.packagePriceKopecks;
                    final dur = _packageListDurationMinutes(p, servicesById);
                    return ListTile(
                      title: Text(p.name, style: const TextStyle(color: AppColors.textPrimary)),
                      subtitle: Text(
                        '${formatMoney(p.packagePriceKopecks)} · ${formatDurationMinutes(dur)}'
                        '${save > 0 ? ' · Экономия ${formatMoney(save)}' : ''}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
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
                          builder: (_) => ServicePackageEditScreen(category: cat),
                        ),
                      ),
                      icon: const Icon(Icons.add, color: AppColors.primary),
                      label: const Text('Добавить комплекс', style: TextStyle(color: AppColors.primary)),
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
  ConsumerState<ServicePackageEditScreen> createState() => _ServicePackageEditScreenState();
}

class _ServicePackageEditScreenState extends ConsumerState<ServicePackageEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _durHoursController;
  late final TextEditingController _durMinutesController;
  final Set<String> _included = {};
  final Map<String, TextEditingController> _addonPriceCtrls = {};
  final Map<String, TextEditingController> _addonDurationCtrls = {};

  static const _sectionStyle = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 16,
    color: AppColors.textPrimary,
  );

  static const _hintStyle = TextStyle(
    fontSize: 13,
    height: 1.35,
    color: AppColors.textSecondary,
  );

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _priceController = TextEditingController(
      text: widget.existing != null
          ? (widget.existing!.packagePriceKopecks / 100).toStringAsFixed(0)
          : '',
    );
    final pm = widget.existing?.packageDurationMinutes ?? 0;
    _durHoursController = TextEditingController(
      text: pm > 0 ? '${pm ~/ 60}' : '',
    );
    _durMinutesController = TextEditingController(
      text: pm > 0 ? '${pm % 60}' : '',
    );
    _included.addAll(widget.existing?.includedServiceIds ?? const []);
    for (final a in widget.existing?.addons ?? const <ServicePackageAddon>[]) {
      _addonPriceCtrls[a.serviceId] = TextEditingController(
        text: (a.extraPriceKopecks / 100).toStringAsFixed(0),
      );
      _addonDurationCtrls[a.serviceId] = TextEditingController(
        text: a.extraDurationMinutes > 0 ? '${a.extraDurationMinutes}' : '',
      );
    }
    _priceController.addListener(() => setState(() {}));
    _durHoursController.addListener(() => setState(() {}));
    _durMinutesController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _durHoursController.dispose();
    _durMinutesController.dispose();
    for (final c in _addonPriceCtrls.values) {
      c.dispose();
    }
    for (final c in _addonDurationCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<ServiceItem> _includedItems(Map<String, ServiceItem> byId) {
    return _included.map((id) => byId[id]).whereType<ServiceItem>().toList();
  }

  @override
  Widget build(BuildContext context) {
    final services = ref
        .read(settingsRepositoryProvider.notifier)
        .servicesForCategory(widget.category.id);
    final byId = {for (final s in services) s.id: s};
    final includedItems = _includedItems(byId);
    final sumKop = includedItems.fold<int>(0, (a, s) => a + s.priceKopecks);
    final sumMin = includedItems.fold<int>(0, (a, s) => a + s.durationMinutes);

    final packageRub = double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0;
    final packageKop = (packageRub * 100).round();
    final savingsKop = sumKop - packageKop;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          widget.existing == null ? 'Новый комплекс' : 'Редактировать комплекс',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Сохранить', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Название комплекса',
              labelStyle: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Что входит в комплекс', style: _sectionStyle),
          const SizedBox(height: 6),
          const Text(
            'Отметьте услуги, которые входят в комплекс по фиксированной цене. Ниже — сумма по прайсу и время.',
            style: _hintStyle,
          ),
          const SizedBox(height: 10),
          ...services.map(
            (s) => CheckboxListTile(
              value: _included.contains(s.id),
              side: const BorderSide(color: AppColors.borderLight),
              fillColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary;
                }
                return Colors.transparent;
              }),
              checkColor: Colors.black,
              title: Text(s.name, style: const TextStyle(color: AppColors.textPrimary)),
              subtitle: Text(
                '${formatMoney(s.priceKopecks)} · ${formatDurationMinutes(s.durationMinutes)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _included.add(s.id);
                    _addonPriceCtrls.remove(s.id)?.dispose();
                    _addonDurationCtrls.remove(s.id)?.dispose();
                  } else {
                    _included.remove(s.id);
                  }
                });
              },
            ),
          ),
          if (_included.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('По выбранным услугам', style: _sectionStyle),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Сумма по прайсу', style: TextStyle(color: AppColors.textSecondary)),
                      Text(
                        formatMoney(sumKop),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Время по отдельным услугам',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  ...includedItems.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              s.name,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                            ),
                          ),
                          Text(
                            formatDurationMinutes(s.durationMinutes),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 24, color: AppColors.border),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Итого по времени', style: TextStyle(color: AppColors.textSecondary)),
                      Text(
                        formatDurationMinutes(sumMin),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text('Стоимость комплекса', style: _sectionStyle),
          const SizedBox(height: 6),
          Text(
            _included.isEmpty
                ? 'Сначала выберите услуги выше — появится сумма по прайсу и расчёт экономии.'
                : 'Укажите цену комплекта для клиента. Экономия считается от суммы по прайсу.',
            style: _hintStyle,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Стоимость данного комплекса, ₽',
              labelStyle: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          if (_included.isNotEmpty && packageKop > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: savingsKop >= 0
                    ? AppColors.success.withValues(alpha: 0.12)
                    : AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: savingsKop >= 0
                      ? AppColors.success.withValues(alpha: 0.35)
                      : AppColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                savingsKop >= 0
                    ? 'Экономия для клиента: ${formatMoney(savingsKop)} по сравнению с покупкой услуг по отдельности'
                    : 'Комплекс дороже суммы по прайсу на ${formatMoney(-savingsKop)} — проверьте цену.',
                style: TextStyle(
                  color: savingsKop >= 0 ? AppColors.success : AppColors.warning,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text('Длительность комплекса', style: _sectionStyle),
          const SizedBox(height: 6),
          Text(
            _included.isEmpty
                ? 'После выбора услуг здесь можно задать длительность записи под комплекс.'
                : 'Оставьте пустым, чтобы использовать сумму длительностей выбранных услуг (${formatDurationMinutes(sumMin)}).',
            style: _hintStyle,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _durHoursController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'ч',
                    hintText: '0',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    helperText: _included.isEmpty ? null : 'Пусто = ${formatDurationMinutes(sumMin)}',
                    helperStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _durMinutesController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'мин',
                    hintText: '0',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 40, color: AppColors.border),
          const Text('Дополнительные услуги к комплексу', style: _sectionStyle),
          const SizedBox(height: 6),
          const Text(
            'Клиент сможет добавить опции с указанной доплатой. Услуги из самого комплекса здесь не показываются.',
            style: _hintStyle,
          ),
          const SizedBox(height: 12),
          if (services.every((s) => _included.contains(s.id)))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _included.isEmpty
                    ? 'Сначала отметьте услуги в комплексе — здесь появятся остальные услуги категории как дополнения.'
                    : 'Все услуги этой категории уже входят в комплекс — дополнений нет.',
                style: _hintStyle,
              ),
            ),
          ...services.where((s) => !_included.contains(s.id)).map((s) {
            final selected = _addonPriceCtrls.containsKey(s.id);
            return Card(
              color: AppColors.cardBg,
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name, style: const TextStyle(color: AppColors.textPrimary)),
                              Text(
                                '${formatMoney(s.priceKopecks)} · ${formatDurationMinutes(s.durationMinutes)}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: selected,
                          thumbColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return AppColors.primary;
                            }
                            return AppColors.textTertiary;
                          }),
                          trackColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return AppColors.primary.withValues(alpha: 0.35);
                            }
                            return AppColors.border;
                          }),
                          onChanged: (v) {
                            setState(() {
                              if (v) {
                                _addonPriceCtrls[s.id] = TextEditingController(text: '0');
                                _addonDurationCtrls[s.id] = TextEditingController();
                              } else {
                                _addonPriceCtrls.remove(s.id)?.dispose();
                                _addonDurationCtrls.remove(s.id)?.dispose();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    if (selected && _addonPriceCtrls.containsKey(s.id))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _addonPriceCtrls[s.id],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: AppColors.textPrimary),
                                decoration: const InputDecoration(
                                  labelText: 'Доплата к комплексу, ₽',
                                  labelStyle: TextStyle(color: AppColors.textSecondary),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 88,
                              child: TextField(
                                controller: _addonDurationCtrls[s.id],
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: AppColors.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'мин +',
                                  hintText: '${s.durationMinutes}',
                                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                                  isDense: true,
                                  helperText: 'к услуге',
                                  helperStyle: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _save() {
    final messenger = ScaffoldMessenger.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Укажите название комплекса')),
      );
      return;
    }
    if (_included.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Отметьте хотя бы одну услугу, входящую в комплекс')),
      );
      return;
    }
    final price =
        (double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0) * 100;
    final h = int.tryParse(_durHoursController.text.trim().replaceAll(RegExp(r'\s'), '')) ?? 0;
    final min = int.tryParse(_durMinutesController.text.trim().replaceAll(RegExp(r'\s'), '')) ?? 0;
    final totalCustom = h * 60 + min;
    final packageDurationMinutes = totalCustom > 0 ? totalCustom.clamp(1, 24 * 60) : 0;

    final addons = <ServicePackageAddon>[];
    for (final e in _addonPriceCtrls.entries) {
      if (_included.contains(e.key)) continue;
      final rub = double.tryParse(e.value.text.replaceAll(',', '.')) ?? 0;
      final durCtrl = _addonDurationCtrls[e.key];
      final extraDur = int.tryParse(durCtrl?.text.trim() ?? '') ?? 0;
      addons.add(
        ServicePackageAddon(
          serviceId: e.key,
          extraPriceKopecks: (rub * 100).round(),
          extraDurationMinutes: extraDur > 0 ? extraDur : 0,
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
      packageDurationMinutes: packageDurationMinutes,
    );
    if (widget.existing == null) {
      repo.addPackage(data);
    } else {
      repo.updatePackage(data);
    }
    if (!context.mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Комплекс сохранён')));
    Navigator.pop(context);
  }
}
