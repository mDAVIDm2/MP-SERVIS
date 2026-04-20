import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/platform_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors_desktop.dart';
import '../../../../core/theme/desktop_light_theme.dart';
import '../../../../core/repositories/settings_repository.dart';
import '../../../../shared/models/settings_models.dart';
import '../../../../shared/models/staff_model.dart';
import '../../../../shared/models/service_catalog_models.dart';
import 'service_catalog_pick_screen.dart';

class ServiceItemEditScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final String categoryName;
  final ServiceItem? existing;

  const ServiceItemEditScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.existing,
  });

  @override
  ConsumerState<ServiceItemEditScreen> createState() =>
      _ServiceItemEditScreenState();
}

class _ServiceItemEditScreenState extends ConsumerState<ServiceItemEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _durationController;
  String? _requiredSkill;
  ServiceCatalogCategoryRef? _catalogCat;
  ServiceCatalogItemRef? _catalogItem;
  bool _useBodyTypePricing = false;
  final List<_BodyPricingDraft> _bodyPricing = [];
  static const List<String> _bodyTypeOptions = [
    'Седан',
    'Хэтчбек',
    'Универсал',
    'Кроссовер',
    'Внедорожник',
    'Купе',
    'Минивэн',
    'Пикап',
    'Фургон',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _priceController = TextEditingController(
      text: widget.existing != null
          ? (widget.existing!.priceKopecks / 100).toString()
          : '',
    );
    _durationController = TextEditingController(
      text: widget.existing?.durationMinutes.toString() ?? '60',
    );
    _requiredSkill = widget.existing?.requiredSkill;
    _useBodyTypePricing = widget.existing?.useBodyTypePricing ?? false;
    final existingPricing =
        widget.existing?.bodyTypePricing ?? const <ServiceBodyTypePricing>[];
    for (final p in existingPricing) {
      _bodyPricing.add(
        _BodyPricingDraft(
          bodyType: p.bodyType,
          priceController: TextEditingController(
            text: (p.priceKopecks / 100).toStringAsFixed(0),
          ),
          durationController: TextEditingController(
            text: p.durationMinutes.toString(),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    for (final draft in _bodyPricing) {
      draft.priceController.dispose();
      draft.durationController.dispose();
    }
    super.dispose();
  }

  Future<void> _openCatalogPicker() async {
    final r = await Navigator.push<(ServiceCatalogCategoryRef, ServiceCatalogItemRef)>(
      context,
      MaterialPageRoute(
        builder: (_) => const ServiceCatalogPickScreen(),
      ),
    );
    if (r == null || !mounted) return;
    final (cat, item) = r;
    setState(() {
      _catalogCat = cat;
      _catalogItem = item;
      _nameController.text = item.name;
      _durationController.text = '${item.defaultDurationMinutes}';
      _requiredSkill = item.requiredSkill ?? _requiredSkill;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    final desk = isDesktopPlatform;
    final mobileNew = isNew && !desk;

    final scaffold = Scaffold(
      backgroundColor: desk
          ? AppColorsDesktop.background
          : AppColors.background,
      appBar: AppBar(
        backgroundColor: desk ? AppColorsDesktop.surface : null,
        foregroundColor: desk ? AppColorsDesktop.textPrimary : null,
        elevation: desk ? 0 : null,
        surfaceTintColor: desk ? Colors.transparent : null,
        title: Text(isNew ? 'Новая услуга' : 'Редактировать услугу'),
        actions: [
          TextButton(
            onPressed: _save,
            style: desk
                ? TextButton.styleFrom(
                    foregroundColor: AppColorsDesktop.primary,
                  )
                : null,
            child: const Text('Сохранить'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.categoryName,
            style: TextStyle(
              fontSize: 14,
              color: desk
                  ? AppColorsDesktop.textSecondary
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.existing?.isFromCatalog == true || (mobileNew && _catalogItem != null)) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: (desk ? AppColorsDesktop.primary : AppColors.primary)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (desk ? AppColorsDesktop.primary : AppColors.primary)
                      .withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                mobileNew
                    ? 'Название из единого справочника MP-Servis. Цену и длительность можно задать ниже.'
                    : 'Название из единого справочника MP-Servis. Чтобы изменить формулировку для всех организаций — отправьте заявку через «Запросить в справочник» в разделе «Услуги и цены».',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: desk
                      ? AppColorsDesktop.textPrimary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ],
          if (mobileNew) ...[
            if (_catalogItem == null)
              Material(
                color: AppColors.nestedBg,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _openCatalogPicker,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.library_books_outlined, color: AppColors.primary.withValues(alpha: 0.9)),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Название услуги',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Выберите позицию из справочника (поиск и разделы)',
                                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              TextField(
                controller: _nameController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Название услуги',
                  filled: true,
                  fillColor: AppColors.nestedBg,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _openCatalogPicker,
                  child: const Text('Сменить услугу из справочника'),
                ),
              ),
            ],
          ] else ...[
            TextField(
              controller: _nameController,
              readOnly: widget.existing?.isFromCatalog == true,
              decoration: InputDecoration(
                labelText: 'Название услуги',
                hintText: 'Например: Замена масла',
                filled: widget.existing?.isFromCatalog == true,
                fillColor: widget.existing?.isFromCatalog == true
                    ? (desk ? AppColorsDesktop.nestedBg : AppColors.nestedBg)
                    : null,
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _priceController,
            decoration: const InputDecoration(
              labelText: 'Цена, ₽',
              hintText: '3500',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _durationController,
            decoration: const InputDecoration(
              labelText: 'Длительность, мин',
              hintText: '60',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _useBodyTypePricing,
            onChanged: (v) => setState(() => _useBodyTypePricing = v),
            contentPadding: EdgeInsets.zero,
            title: const Text('Разные цена и длительность по кузову'),
            subtitle: const Text(
              'Например: седан и универсал с разной стоимостью',
            ),
          ),
          if (_useBodyTypePricing) ...[
            ..._bodyPricing.map((entry) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: entry.bodyType.isEmpty ? null : entry.bodyType,
                        items: _bodyTypeOptions
                            .map(
                              (b) => DropdownMenuItem<String>(
                                value: b,
                                child: Text(b),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => entry.bodyType = v ?? ''),
                        decoration: const InputDecoration(
                          labelText: 'Тип кузова',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: entry.priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Цена, ₽'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: entry.durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Длительность, мин',
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              _bodyPricing.remove(entry);
                            });
                            entry.priceController.dispose();
                            entry.durationController.dispose();
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _bodyPricing.add(
                    _BodyPricingDraft(
                      bodyType: '',
                      priceController: TextEditingController(),
                      durationController: TextEditingController(
                        text: _durationController.text.trim().isEmpty
                            ? '60'
                            : _durationController.text.trim(),
                      ),
                    ),
                  );
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Добавить тип кузова'),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Требуемый навык мастера',
            style: TextStyle(
              fontSize: 14,
              color: desk
                  ? AppColorsDesktop.textSecondary
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Theme(
            data: desk
                ? desktopLightUiTheme().copyWith(
                    chipTheme: ChipThemeData(
                      backgroundColor: AppColorsDesktop.nestedBg,
                      selectedColor: AppColorsDesktop.primary.withValues(
                        alpha: 0.18,
                      ),
                      checkmarkColor: AppColorsDesktop.primary,
                      labelStyle: const TextStyle(
                        color: AppColorsDesktop.textPrimary,
                        fontSize: 13,
                      ),
                      secondaryLabelStyle: const TextStyle(
                        color: AppColorsDesktop.textSecondary,
                        fontSize: 13,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                      side: const BorderSide(color: AppColorsDesktop.border),
                    ),
                  )
                : Theme.of(context),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Не задан'),
                  selected: _requiredSkill == null,
                  onSelected: (v) => setState(() => _requiredSkill = null),
                ),
                ...kSkillIds.map((id) {
                  final selected = _requiredSkill == id;
                  return ChoiceChip(
                    label: Text(skillLabel(id)),
                    selected: selected,
                    onSelected: (v) =>
                        setState(() => _requiredSkill = v == true ? id : null),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );

    if (desk) {
      return themeDesktopLight(child: scaffold);
    }
    return scaffold;
  }

  void _save() {
    final isNew = widget.existing == null;
    final desk = isDesktopPlatform;
    final mobileNew = isNew && !desk;

    if (mobileNew) {
      if (_catalogItem == null || _catalogCat == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите услугу из справочника')),
        );
        return;
      }
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final priceRub =
        double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0;
    final priceKopecks = (priceRub * 100).round();
    final duration = int.tryParse(_durationController.text) ?? 60;
    final bodyPricing = <ServiceBodyTypePricing>[];
    if (_useBodyTypePricing) {
      for (final entry in _bodyPricing) {
        final bt = entry.bodyType.trim();
        if (bt.isEmpty) continue;
        final rub =
            double.tryParse(entry.priceController.text.replaceAll(',', '.')) ??
            0;
        final kopecks = (rub * 100).round();
        final d = int.tryParse(entry.durationController.text) ?? duration;
        bodyPricing.add(
          ServiceBodyTypePricing(
            bodyType: bt,
            priceKopecks: kopecks,
            durationMinutes: d,
          ),
        );
      }
    }

    final repo = ref.read(settingsRepositoryProvider.notifier);
    if (widget.existing != null) {
      repo.updateService(
        widget.existing!.copyWith(
          name: name,
          priceKopecks: priceKopecks,
          durationMinutes: duration,
          requiredSkill: _requiredSkill,
          useBodyTypePricing: _useBodyTypePricing,
          bodyTypePricing: bodyPricing,
        ),
      );
    } else if (mobileNew && _catalogCat != null && _catalogItem != null) {
      final catId = repo.categoryIdForCatalogCategory(_catalogCat!);
      repo.addServiceFromCatalog(
        categoryId: catId,
        catalogItemId: _catalogItem!.id,
        name: _catalogItem!.name,
        priceKopecks: priceKopecks,
        durationMinutes: duration,
        requiredSkill: _requiredSkill ?? _catalogItem!.requiredSkill,
      );
    } else {
      final id = 's_${DateTime.now().millisecondsSinceEpoch}';
      repo.addService(
        ServiceItem(
          id: id,
          categoryId: widget.categoryId,
          name: name,
          priceKopecks: priceKopecks,
          durationMinutes: duration,
          requiredSkill: _requiredSkill,
          useBodyTypePricing: _useBodyTypePricing,
          bodyTypePricing: bodyPricing,
        ),
      );
    }
    Navigator.pop(context);
  }
}

class _BodyPricingDraft {
  String bodyType;
  TextEditingController priceController;
  TextEditingController durationController;

  _BodyPricingDraft({
    required this.bodyType,
    required this.priceController,
    required this.durationController,
  });
}
